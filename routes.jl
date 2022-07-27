using Genie
using Genie.Router
using Genie.Requests
using Genie.Renderer.Html
using Genie.Renderer.Json
using Match
using PrettyTables
using CSV
using DataFrames
using SQLite
using IterableTables
using URIs

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
  # io = IOBuffer();
  # pretty_table(io, matched_df, nosubheader=true, backend=:html)
  # rm("$(payload(:dataset)).txt")
  # String(take!(io))
  CSV.write("public/matched_dataset.csv", matched_df)
  densities = Match.ps_density(matched_df, "sp", "O", "B")
  p1 = sprint(show, "text/html", densities[1])
  p2 = sprint(show, "text/html", densities[2])
  html(path"app/resources/post_matching.jl.html",before=p1,after=p2, layout = path"app/layouts/app.jl.html")
 # html("<a href='/matched_dataset.csv' download='test.csv'>Save to your computer</a>", layout = path"app/layouts/app.jl.html")
end