using GLib;

/**
 * Importing files.
 */
void importing_files(EnergyStorage es, string[] argv, uint offset)
{
	uint total = 0;
	es.start_transaction();
	for(uint i = offset ; i < argv.length; i++)
	{
		stdout.printf("Importing file: '%s': ", argv[i]);
		try {
			uint retv = es.parse_from_json(argv[i]);
			if(retv  > 0) {
				stdout.printf("%u points\n", retv);
			} else {
				stdout.printf("no new points\n");
			} 
			total+= retv;
		}catch (GLib.Error e)
		{
			stdout.printf("Failed to import file: '%s'\n", e.message);
		}
	}
	es.stop_transaction();
	stdout.printf("Imported a total of %u points\n", total);
}

/**
 * Parse range.
 * Only supports dates atm.
 */
uint parse_range(string[] argv, uint offset, out DateTime start, out DateTime stop)
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

/**
 * Statistics. 
 */

void statistics(EnergyStorage es, string[] argv, uint offset)
{
	bool do_day  = false;
	bool do_week = false;

	DateTime tstart = es.get_starting_datetime();
	DateTime tstop  = es.get_stopping_datetime();

	// Parse range.
	for(uint i = offset; i < argv.length; i++)
	{
		if(argv[i] == "range") {
			i += parse_range(argv, i+1, out tstart, out tstop);
		}
		else if (argv[i] == "day") {
			do_day = true;
		}
		else if (argv[i] == "week") {
			do_week = true;
		}
	}
	tstart = es.get_starting_datetime(tstart);
	tstop = es.get_stopping_datetime(tstop);

	double avg = es.get_average_energy(tstart, tstop);
	double eng = es.get_energy(tstart, tstop);
	stdout.printf("Range:           %s --> %s\n", tstart.format("%d/%m/%Y - %H:%M"),tstop.format("%d/%m/%Y - %H:%M"));
	stdout.printf("Average power:   %8.02f W\n", avg);
	stdout.printf("Energy consumed: %8.02f kWh\n", eng/1000.0);


	// Day statistics.
	if(do_day)
	{
		double hour[24] = {0};
		int num_hour[24] = {0};
		

		stdout.printf("======= Day hours =======\n");

		var start = tstart;
		var stop = start.add_minutes(-start.get_minute());
		while(stop.compare(tstop)< 0)
		{
			start = stop;
			int d = start.get_hour();
			stop  = start.add_hours(1);

			hour[d] += es.get_average_energy(start, stop);
			num_hour[d]++;

		}

		for(uint i = 0; i < 24; i++)
		{
			if(num_hour[i] > 0)
				stdout.printf("%2u %8.02f\n", i, hour[i]/(double)num_hour[i]);

		}
	}
	
	if(do_week)
	{
		double week[7] = {0};
		int num_week[7] = {0};

		stdout.printf("======= Week days =======\n");

		var start = tstart;
		var stop = start.add_minutes(-start.get_minute());
		while(stop.compare(tstop)< 0)
		{
			start = stop;
			int d = start.get_day_of_week();
			stop  = start.add_days(1);

			week[d-1] += es.get_average_energy(start, stop);
			num_week[d-1]++;

		}

		for(uint i = 0; i < 7; i++)
		{
			if(num_week[i] > 0)
				stdout.printf("%2u %8.02f\n", i+1, week[i]/(double)num_week[i]);

		}

	}

}

/**
 * Plotting graph
 */
void plot_graph(EnergyStorage es, string[] argv, uint offset)
{
	bool do_average = false;
	bool do_bars    = false;
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
		// Parse range.
		else if(argv[i] == "range") 
		{
			i += parse_range(argv, i+1, out tstart, out tstop);
		}
		else
		{
			stdout.printf("Failed to parse commandline: %s\n", argv[i]);
		}

	}
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
	double eng = es.get_energy(tstart, tstop);

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
		ds3.add_point((double)stop.to_unix(), avg);

		while(stop.compare(tstop)< 0)
		{
			start = stop;
			stop  = start.add_hours(1);

			avg = es.get_energy(start,stop);
			ds3.add_point((double)stop.to_unix(), avg);
		}
	}

	// add zero point.
	ds.add_point((double)tstart.to_unix(), 0);
	foreach ( EnergyPoint ep in es.get_data(tstart, tstop))
	{
		ds.add_point((double)ep.time.to_unix(), ep.power);
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
		/**
		 * Importing new files
		 */
		if(argv[1] == "import")
		{
			importing_files(es, argv, 2);
		}

		/**
		 * Plot graphs
		 */
		else if (argv[1] == "graph")
		{
			plot_graph(es, argv, 2);

		}

		/**
		 * Statistics 
		 */
		else if (argv[1] == "statistics")
		{
			statistics(es, argv, 2);

		}

		/** 
		 * Invalid commands.
		 */
		else
		{
			stdout.printf("'%s' is an invalid command.", argv[1]);
			return 1;
		}

		return 0;
	}
	else
	{
		stdout.printf("Usage: %s <command> <options>", argv[0]);	
		return 1;
	}

	return 0;
}
