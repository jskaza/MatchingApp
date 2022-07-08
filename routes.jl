using Genie
using Genie.Router
using Genie.Requests
using Genie.Renderer.Html
using Genie.Renderer.Json
using Match
using PrettyTables
using CSV
using DataFrames

route("/") do 
  html(path"app/resources/file_form.jl.html", layout = path"app/layouts/app.jl.html")
end

route("/", method = POST) do
  if infilespayload(:dataset)
    write(filespayload(:dataset))

    df = CSV.read(filename(filespayload(:dataset)), DataFrame; delim = '\t', header = true)

    col_names = names(df)
    html(path"app/resources/matching_form.jl.html", col_names = col_names, df=filespayload(:dataset), layout = path"app/layouts/app.jl.html")

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


