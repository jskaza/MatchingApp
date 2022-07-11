using Genie
using Genie.Router
using Genie.Requests
using Genie.Renderer.Html
using Genie.Renderer.Json
using PrettyTables
using CSV
using DataFrames
using DataFramesMeta
using GLM
using StatsFuns
using Statistics

# TODO
# figure out how to read in types
#data = vec(readdlm("coltypes.csv", ',', String))
#add type validations df::DataFrame
# add exceptions for unique ids, etc
# deal with missings
# replacement
# exact covariates
# iptw
# pairs dataset

function make_dataset(df, _id_col_name, label_col_name, case, control, X)
    @subset!(df, $label_col_name  .== case .|| $label_col_name .== control)
    df = df[:, vcat(_id_col_name, label_col_name, X)]
    return df
end

function fit_logit(df, _id_col_name, label_col_name, case)
    df = @transform(df, $label_col_name = ($label_col_name .== case))
    X = term.(names(df[:, Not([_id_col_name,label_col_name])]))
    mod = glm(term(label_col_name) ~ foldl(+, X), df, Binomial(), LogitLink())
    return mod
end

function propensity_scores(df, model, _id_col_name, label_col_name; ps_col_name="propensityScore")
    ps = DataFrame(ps_col_name => predict(model))
    return hcat(df[:, [_id_col_name,label_col_name]], ps)
end

function greedy_match(df,n,exact,replacement,_id_col_name,label_col_name,ps_col_name,case,control;caliper="calc")
    if caliper == "calc"
        caliper = 0.2*std(logit.(df[:, ps_col_name]))
    end
    cases = @subset(df, $label_col_name .== case)
    ps_cases = collect(enumerate(cases[:, ps_col_name]))
    controls = @subset(df, $label_col_name .== control)
    ps_controls = collect(enumerate(controls[:, ps_col_name]))
    cases_to_drop = []
    if replacement
        controls_to_keep = []
    end
    for ps in ps_cases
        diffs = (abs.(last.(ps_controls) .- last(ps)))
        candidate_idx, candidate_diffs = (findall(x -> x <= caliper, diffs), diffs[diffs .<= caliper])
        if length(candidate_idx) >= n
            sorted_candidates = sort(collect(zip(candidate_idx, candidate_diffs)); by=last)
            matches = sorted_candidates[1:n]
            !replacement ? deleteat!(ps_controls, sort(first.(matches))) : append!(controls_to_keep, first.(matches))
        elseif length(candidate_idx) > 0 && !exact
            matches = candidate_idx
            !replacement ? deleteat!(ps_controls, sort(candidate_idx)) : append!(controls_to_keep, first.(matches))
        else
            append!(cases_to_drop, first(ps))
        end
    end
    if replacement
        return vcat(cases[Not(cases_to_drop), :], controls[controls_to_keep, :])
    else
        return vcat(cases[Not(cases_to_drop), :], controls[Not(first.(ps_controls)), :])
    end
end

function merge_propensity_scores(df, ps_df, on)
    return leftjoin(df, ps_df, on = on)
end

function add_matches(df, match_df, _id_col_name, label_col_name)
    to_add = df[findall(in(match_df[:, _id_col_name]), df[:, _id_col_name]), :]
    to_add[:, label_col_name] = string.(to_add[:, label_col_name]," Matched")
    return vcat(df, to_add)
end

function main(df,
    _id_col_name,label_col_name,case,control,covariates,
    n,n_exact,replacement;
    ps_col_name="propensityScore",caliper="calc")

    # df = CSV.read(file, DataFrame; delim = '\t', header = true, stringtype = String)
    ps_df = make_dataset(df, _id_col_name, label_col_name, case, control, covariates)
    mod = fit_logit(ps_df, _id_col_name, label_col_name, case)
    ps_df = propensity_scores(ps_df, mod, _id_col_name, label_col_name, ps_col_name=ps_col_name)
    match_df = greedy_match(ps_df, n, n_exact, replacement, _id_col_name, label_col_name, ps_col_name, case, control, caliper=caliper)
    df = merge_propensity_scores(df, ps_df, [_id_col_name, label_col_name])
    return add_matches(df, match_df, _id_col_name, label_col_name)
end

function launchServer(port)

    Genie.config.run_as_server = true
    Genie.config.server_host = "0.0.0.0"
    Genie.config.server_port = port

    println("port set to $(port)")



    route("/") do 
        html(path"app/resources/file_form.jl.html", layout = path"app/layouts/app.jl.html")
    end
      
    route("/specs", method = POST) do
        # if infilespayload(:dataset)
        write(filespayload(:dataset))
        _id = split(filename(filespayload(:dataset)), ".txt")[1]
        redirect(linkto(:matching_spec, _id = _id))
        # end
    end 
      
      # route("/specs") do
      #   # if infilespayload(:dataset)
      #   # write(filespayload(:dataset))
      #   # _id = split(filename(filespayload(:dataset)), ".txt")[1]
      #   html("ddd")
      #   # linkto(:dataset_matching, _id = _id)
      #   # end
      # end 
      
    route("/specs/:_id", named = :matching_spec) do
        df = CSV.read("$(payload(:_id)).txt", DataFrame; delim = '\t', header = true, stringtype=String)
        col_names = names(df)
        html(path"app/resources/matching_form.jl.html", dataset = payload(:_id), col_names = col_names, layout = path"app/layouts/app.jl.html")
    end
    
    route("/results", method = POST) do  
        form = postpayload()
        dataset = form[:dataset]
        id = form[:_id]
        y = form[:target]
        case = form[:case]
        control = form[:control]
        X = join(form[Symbol("covariates[]")], "%2B")
        n = form[:ratio]
        n_exact = haskey(form, "n_exact") ? "true" : "false"
        replacement = (haskey(form, "replacement") ? "true" : "false")
        redirect("/results/dataset/"*dataset*"/id/"*id*"/y/"*y*"/case/"*case*"/control/"*control*"/X/"*X*"/n/"*n*"/n_exact/"*n_exact*"/replacement/"*replacement)
        # redirect(linkto(:matching_results, dataset=dataset,id=id,y=y,case=case,control=control,X=X,n=n,n_exact=n_exact,replacement=replacement))
        # NEED TO CIRCUMVENT EXPLICIT CASE CONVERSION
        # matching = Match.main(df,id,y,case,control,X,n,n_exact,replacement);
        # io = IOBuffer();
        # pretty_table(io, matching, nosubheader=true, backend=:html)
        # String(take!(io))
    end
    
    route("/results/dataset/:dataset/id/:id/y/:y/case/:case/control/:control/X/:X/n/:n/n_exact/:n_exact/replacement/:replacement", named = :matching_results) do
    
        df = CSV.read("$(payload(:dataset)).txt", DataFrame; delim = '\t', header = true, stringtype=String)
        X = split(payload(:X),"%2B")
        n = parse(Int64, payload(:n))
        n_exact = payload(:n_exact) == "true"
        replacement = payload(:replacement) == "true"
        matched_df = Match.main(df,payload(:id),payload(:y),payload(:case),payload(:control),X,n,n_exact,replacement)
        io = IOBuffer();
        pretty_table(io, matched_df, nosubheader=true, backend=:html)
        rm("$(payload(:dataset)).txt")
        String(take!(io))
        # CSV.write("matched_dataset.csv", matched_df)
    end
      

    Genie.AppServer.startup()
end

launchServer(parse(Int, ARGS[1]))