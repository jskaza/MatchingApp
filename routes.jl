using Genie
using Genie.Router
using Genie.Requests
using Genie.Renderer.Html
using Genie.Renderer.Json
using Match
using PrettyTables
using CSV
using DataFrames

# <head>
#   <meta charset="utf-8">
#   <meta http-equiv="X-UA-Compatible" content="IE=edge">
#   <meta name="viewport" content="width=device-width, initial-scale=1">
#   <title>Genie :: The highly productive Julia web framework</title>

#   <!-- Bootstrap -->
#   <link href="/css/genie/bootstrap.min.css" rel="stylesheet">
#   <link href="/css/genie/style.css" rel="stylesheet">
#   <link href="/css/genie/prism.css" rel="stylesheet" />
# </head>

# <div class="container-fluid">
#     <!-- Start: Header -->
#     <div class="row hero-header" id="home">
#       <div class="col-md-7">
#         <h1 id="main-heading">Welcome!</h1>
#         <h3>It works! You have successfully created and started your Genie app. </h3>
#       </div>
#     </div>
#     <!-- End: Header -->
# </div>

form = """
<div>
<form action="/" method="POST" enctype="multipart/form-data">
  <input type="file" name="dataset" /><br/>
  <input type="submit" value="Submit" />
</form>
"""

form = """
<div class="container-fluid">
<script src="js/select2.js"></script>

<form>
<input type="checkbox" id=replacement" name="replacement" value="replacement">
<label for="replacement">Replacement</label><br>

<input type="checkbox" id=n_exact" name="n_exact" value="n_exact">
<label for="n_exact">N Exact</label><br>

<select class="js-example-basic-multiple" name="states[]" multiple="multiple"  style="width: 75%>
  <option value="AL">Alabama</option>
  <option value="WY">Wyoming</option>
</select>
</form> 
</div>
"""

route("/") do 
  html(path"app/resources/file_form.jl.html", layout = path"app/layouts/app.jl.html")
end

route("/", method = POST) do
  if infilespayload(:dataset)
    write(filespayload(:dataset))
    io = IOBuffer();
    df = CSV.read(filename(filespayload(:dataset)), DataFrame; delim = '\t', header = true)

    pretty_table(io, describe(df), backend = :html)
    tab = String(take!(io))
    html(tab, layout = path"app/layouts/app.jl.html")
    # for i in names(df)
    #   render(i)
    # end
    # X = ["sex","FL","RW","BD"]
    # io = IOBuffer();
   

  else
    "No file uploaded"
  end
end


