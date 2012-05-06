using GLib;
using Graph;
using Json;
using Gtk;

class LiveYouLess : GLib.Object
{
	public string url = "http://192.150.0.40/a?f=j";
	private Gtk.Window win;
	private int current_power = 0;
	private uint index = 0;
	private Graph.Graph graph = new Graph.Graph(); 
	private Graph.DataSet ds = null;

	public LiveYouLess()
	{
		win = new Gtk.Window(Gtk.WindowType.TOPLEVEL);


		win.set_app_paintable(true);


		ds = new Graph.DataSetArea<int>();

		ds.min_x_point = 0.0;

		graph.add_data_set(ds);

		win.draw.connect(draw);

		// Handle window destroy
		win.delete_event.connect((source)=>{
			Gtk.main_quit();
			return false;
		});

		// Show window.
		win.show_all();

		GLib.Timeout.add_seconds(1,()=> {
			load_from_file();
			return true;
		});
	}


	private async void load_from_file()
	{
		GLib.File f = GLib.File.new_for_uri(url);

		uint8[] contents;
		yield f.load_contents_async(null, out contents);


		string json = (string)contents;
		stdout.printf("json: %s\n", json);

		// Json Parser 
		var js = new Json.Parser();
		js.load_from_data(json);

		// Get root. 
		var node = js.get_root();

		// No data in json file. abort().
		if(node == null) return;

		// Get power element.	
		var obj = node.get_object();
		current_power = (int)obj.get_int_member("pwr");
		graph.title_label = "%04d W".printf(current_power);
		/*if(initial_value == 0) {
			initial_value = current_power;

		}*/

		ds.add_point(index, current_power);


		if(ds.points.length() > 100)
		{
			ds.points.remove_link(ds.points.first());

			ds.recalculate();
		}
		index++;
		this.win.queue_draw();
	}



	private bool draw ( Cairo.Context ct)
	{
		// 
		Gtk.Allocation alloc;
		this.win.get_allocation(out alloc);
		this.graph.repaint(ct, alloc);

		return false;
	}



}


int main ( string[] argv)
{
	Gtk.init(ref argv);

	var yl = new LiveYouLess();

	if(argv.length > 1) {
		yl.url = argv[1];		

	}


	Gtk.main();

	yl = null;

	return 0;
}
