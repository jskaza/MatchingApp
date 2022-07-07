using Genie
using Genie.Router
using Genie.Requests
using Genie.Renderer.Html
using Genie.Renderer.Json
using Match

function launchServer(port)

    Genie.config.run_as_server = true
    Genie.config.server_host = "0.0.0.0"
    Genie.config.server_port = port

    println("port set to $(port)")
    
    form = """
    <form action="/" method="POST" enctype="multipart/form-data">
    <input type="file" name="yourfile" /><br/>
    <input type="submit" value="Submit" />
    </form>
    """

    route("/") do
    html(form)
    end

    route("/", method = POST) do
    if infilespayload(:yourfile)
        write(filespayload(:yourfile))
        types = [Float64, String, String, Float64, Float64,Float64, Float64, Float64]
        X = ["sex","FL","RW","BD"]
        Match.main(filename(filespayload(:yourfile)), types,"id","sp","B","O",X,1,true,false)
    else
        "No file uploaded"
    end
    end

    Genie.AppServer.startup()
end

launchServer(parse(Int, ARGS[1]))