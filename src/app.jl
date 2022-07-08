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

    route("/", method = POST) do
        if infilespayload(:dataset)
            write(filespayload(:dataset))

            df = CSV.read(filename(filespayload(:dataset)), DataFrame; delim = '\t', header = true)

            col_names = names(df)
            html(path"app/resources/matching_form.jl.html", col_names = col_names, layout = path"app/layouts/app.jl.html")

            # pretty_table(io, describe(df), backend = :html)
            # tab = String(take!(io))
            # html(tab, layout = path"app/layouts/app.jl.html")
            # for i in names(df)
            #   render(i)
            # end
            # X = ["sex","FL","RW","BD"]

        else

            write(filespayload(:dataset2))

            df = CSV.read(filename(filespayload(:dataset2)), DataFrame; delim = '\t', header = true, stringtype=String)

            form = postpayload()
            id = form[:_id]
            y = form[:target]
            case = form[:case]
            control = form[:control]
            X = form[Symbol("covariates[]")]
            n = parse(Int64, form[:ratio])
            n_exact = haskey(form, "n_exact")
            replacement = haskey(form, "replacement")
            matching = Match.main(df,id,y,case,control,X,n,n_exact,replacement);
            io = IOBuffer();
            pretty_table(io, matching, nosubheader=true, backend=:html)
            String(take!(io))
        end 
    end


    Genie.AppServer.startup()
end

launchServer(parse(Int, ARGS[1]))