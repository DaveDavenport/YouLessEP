using GLib;

abstract class Base 
{

	public abstract void print_help();
	public abstract bool parse_arguments(string[] argv);
	public abstract int execute();
}



/**
 * Parse range.
 * Only supports dates atm.
 */
uint parse_range(string[] argv, uint offset, ref DateTime start, ref DateTime stop)
{
	uint retv = 0;
	if(argv.length >= (offset+1)) 
	{	
		
		GLib.Date d = GLib.Date();
		d.set_parse(argv[offset]);
		start = new GLib.DateTime.local(d.get_year(), d.get_month(), d.get_day(), 0, 0, 0);

		d = GLib.Date();
		d.set_parse(argv[offset+1]);
		stop = new GLib.DateTime.local(d.get_year(), d.get_month(), d.get_day(), 0, 0, 0);

		retv+=2;
	}

	return retv;
}

void plot_weekday(EnergyStorage es, string[] argv, uint offset)
{
	DateTime tstart = es.get_starting_datetime();
	DateTime tstop  = es.get_stopping_datetime();

	// Parse range.
	for(uint i = offset; i < argv.length; i++)
	{
		if(argv[i] == "range") {
			i += parse_range(argv, i+1, ref tstart, ref tstop);
		}
	}

	double week[7] = {0};
	int num_week[7] = {0};

	var start = tstart;
	var stop = start.add_minutes(-start.get_minute());
	stop = stop.add_hours(-stop.get_hour());
	while(stop.compare(tstop)< 0)
	{
		start = stop;
		int d = start.get_day_of_week();
		stop  = start.add_days(1);

		week[d-1] += es.get_average_energy(start, stop);
		num_week[d-1]++;

	}

	// Draw graph.
	Gtk.init(ref argv);
	Gtk.Window win = new Gtk.Window();

	win.delete_event.connect((source) =>{
		Gtk.main_quit();
		return false;
	});
	// Set default size
	win.set_default_size(800, 600);

	var a = new Graph.Widget();

	a.graph.title_label = "Power consumption";
	a.graph.y_axis_label = "Energy (kWh)";
	a.graph.x_axis_label = "Week day";

	a.graph.min_y_point = 0;
	var ds = a.graph.create_data_set_bar();
	ds.set_color(0.4,0.5,0.3);

	a.graph.add_xticks(0.5, "Monday");
	a.graph.add_xticks(1.5, "Tuesday");
	a.graph.add_xticks(2.5, "Wednesday");
	a.graph.add_xticks(3.5, "Thursday");
	a.graph.add_xticks(4.5, "Friday");
	a.graph.add_xticks(5.5, "Saturday");
	a.graph.add_xticks(6.5, "Sunday");
	ds.add_point(0, 0);
	for(uint i = 0; i < 7; i++)
	{
		if(num_week[i] > 0)
		{
		ds.add_point(i+1, 
				24/1000.0*week[i]/(double)num_week[i]);
		}else{
			ds.add_point(i+1, 0);	
		}
	}
	win.add(a);

	win.show_all();
	Gtk.main();
}

/**
 * Plotting graph
 */
void plot_graph(EnergyStorage es, string[] argv, uint offset)
{
	bool do_average = false;
	bool do_bars    = false;
	bool do_points  = false;
	DateTime tstart = es.get_starting_datetime();
	DateTime tstop  = es.get_stopping_datetime();

	for(uint i = offset; i < argv.length; i++)
	{
		if(argv[i] == "average")
		{
			do_average = true;
		}
		// Plot hour bars.
		else if (argv[i] == "bars") 
		{
			do_bars = true;
		}
		else if (argv[i] == "points") 
		{
			do_points = true;
		}
		// Parse range.
		else if(argv[i] == "range") 
		{
			i += parse_range(argv, i+1, ref tstart, ref tstop);
		}
		else
		{
			stdout.printf("Failed to parse commandline: %s\n", argv[i]);
		}

	}
	if(!do_bars) do_points = true;
	tstart = es.get_starting_datetime(tstart);
	tstop = es.get_stopping_datetime(tstop);

	// Draw graph.
	Gtk.init(ref argv);
	Gtk.Window win = new Gtk.Window();

	win.delete_event.connect((source) =>{
		Gtk.main_quit();
		return false;
	});
	// Set default size
	win.set_default_size(800, 600);

	double avg = es.get_average_energy(tstart, tstop);
	//double eng = es.get_energy(tstart, tstop);

	var a = new Graph.Widget();

	a.graph.title_label = "Power consumption";
	a.graph.y_axis_label = "Power (W)";
	a.graph.x_axis_label = "Time (HH:MM)";

	a.graph.min_y_point = 0;
	var ds = a.graph.create_data_set_area();
	ds.set_color(0.4,0.5,0.3);

	// if we need average.
	if(do_average)
	{
		var ds2 = new Graph.DataSetAverage(ds);
		a.graph.add_data_set(ds2);
		ds2.set_color(0.2,0.2,0.4);
	}
	if (do_bars)
	{
		var ds3 = a.graph.create_data_set_bar();
		ds3.set_color(0.5,0.2,0.2);


		var start = tstart;
		var stop = start.add_minutes(-start.get_minute());
		ds3.add_point((double)stop.to_unix(), 0);

		while(stop.compare(tstop)< 0)
		{
			start = stop;
			stop  = start.add_hours(1);

			avg = es.get_energy(start,stop);
			ds3.add_point((double)stop.to_unix(), avg);
		}
	}

	// add zero point.
	if(do_points)
	{
		ds.add_point((double)tstart.to_unix(), 0);
		foreach ( EnergyPoint ep in es.get_data(tstart, tstop))
		{
			ds.add_point((double)ep.time.to_unix(), ep.power);
		}
	}

	var start = tstart;
	var stop = start.add_minutes(-start.get_minute());
	// ticks.
	while(stop.compare(tstop)< 0)
	{
		start = stop;
		stop  = start.add_hours(1);
		string sa = "%02d:%02d".printf(start.get_hour(), start.get_minute());
		a.graph.add_xticks((double)start.to_unix(),sa);

	}


	win.add(a);

	win.show_all();
	Gtk.main();

}


int main (string[] argv)
{
	EnergyStorage es = new EnergyStorage("es.sqlite3");
	if(argv.length > 1)
	{
		Base module = null;
		/**
		 * Importing new files
		 */
		if(argv[1] == "import")
		{
			module = new Import(es);
		}

		/**
		 * Plot graphs
		 */
		else if (argv[1] == "graph")
		{
			if(argv.length > 1 && argv[2] == "weekday")
			{
				plot_weekday(es, argv, 2);
			}else{
				plot_graph(es, argv, 2);
			}
		}

		/**
		 * Statistics 
		 */
		else if (argv[1] == "statistics")
		{
			module = new Statistics(es);
		}

		/** 
		 * Invalid commands.
		 */
		else
		{
			stdout.printf("'%s' is an invalid command.", argv[1]);
			return 1;
		}

		if(module != null)
		{
			if(module.parse_arguments(argv[2:argv.length]))
			{
				return module.execute();
			}
		}
		return 1;
	}
	else
	{
		stdout.printf("Usage: %s <command> <options>", argv[0]);	
		return 1;
	}
}
