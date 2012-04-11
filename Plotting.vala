using GLib;
using Gtk;

class Plotting : Module
{
	private enum PlotType {
		POINTS,
			AVG_WEEKDAY,
			DAYS,
			WEEKS,
			MONTHS,
			NUM_PLOT_TYPES	
	}

	private EnergyStorage es = null;

	private bool do_svg = false;
	private PlotType plot_type = PlotType.POINTS;
	private DateTime tstart;
	private DateTime tstop;


	public Plotting(EnergyStorage es)
	{
		this.es = es;

	}

	public override void print_help()
	{
		stdout.printf("""
				Usage plotting:
				ep plotting <options> <commands>

				commands:
points:         Plot all the data points. (use in combination with range)
weekday:        Shows the average power consumption for each day of the week.
weeks:	        Shows the energy consumption for each week of the year.

Options:
--help, help	print this help message.
range <start date> <end date>	limit the evaluated data to a certain range.
svg	                            outputs the graph to an SVG file.

Example:
""");
	}

	public override bool parse_arguments(string[] argv)
	{
		tstart = es.get_starting_datetime();
		tstop = es.get_stopping_datetime();
		for(uint  i = 0; i < argv.length; i++)
		{
			if(argv[i] == "help" || argv[i] == "--help") {
				print_help();
				return false;
			} else if (argv[i] == "range") {
				i += parse_range(argv, i+1, ref tstart, ref tstop);
			} else if (argv[i] == "weekday") {
				plot_type = PlotType.AVG_WEEKDAY;	
			}else if (argv[i] == "points") {
				plot_type = PlotType.POINTS;
			}else if (argv[i] == "weeks") {
				plot_type = PlotType.WEEKS;
			}else if (argv[i] == "days") {
				plot_type = PlotType.DAYS;
			}else if (argv[i] == "svg") {
				do_svg = true;	
			} else {
				print_help();
				return false;
			}
		}
		if(!do_svg)
		{
			Gtk.init(ref argv);
		}
		return true;
	}
	public override int execute()
	{
		stdout.printf("Range:            %s --> %s\n", tstart.format("%d/%m/%Y - %H:%M"),tstop.format("%d/%m/%Y - %H:%M"));

		Graph.Widget widget   = null;
		Graph.Svg    svg_plot = null;
		Graph.Graph  graph    = null;
		if(do_svg) 
		{
			svg_plot = new Graph.Svg();	
			graph = svg_plot.graph;
		}else{
			widget = new Graph.Widget();
			graph = widget.graph;
		}
		if(plot_type == PlotType.POINTS)
		{
			plot_graph(graph);
		}
		else if (plot_type ==  PlotType.AVG_WEEKDAY)
		{
			plot_weekday(graph);
		}
		else if (plot_type ==  PlotType.WEEKS)
		{
			plot_weeks(graph);
		}

		if(!do_svg)
		{
			Gtk.Window win = new Gtk.Window();

			win.delete_event.connect((source) =>{
					Gtk.main_quit();
					return false;
					});
			// Set default size
			win.set_default_size(800, 600);
			win.add(widget);
			win.show_all();
			Gtk.main();
		}else{
			svg_plot.output("output.svg", 800, 600);
		}
		return 0;
	}
	private void plot_weeks(Graph.Graph graph)
	{
		var start = tstart;
		var stop = start.add_minutes(-start.get_minute());
		stop = stop.add_hours(-stop.get_hour());
		stop = stop.add_days(-stop.get_day_of_week()+1);

		graph.title_label = "Power consumption";
		graph.y_axis_label = "Energy (kWh)";
		graph.x_axis_label = "Week";

		var ds3 = graph.create_data_set_bar();
		ds3.set_color(0.5,0.2,0.2);
		ds3.add_point(stop.to_unix(), 0);
		while(stop.compare(tstop)< 0)
		{
			start = stop;
			stop  = start.add_days(7);

			stdout.printf("Range:            %s --> %s\n", start.format("%V %d/%m/%Y - %H:%M"),stop.format("%d/%m/%Y - %H:%M"));
			var avg = es.get_average_energy(start,stop)*24*7/1000.0;
			stdout.printf("power: %.2f kWh\n", avg);
			ds3.add_point((double)stop.to_unix(), avg);
			graph.add_xticks((double)start.to_unix()+(3.5*24*60*60), start.format("%V"));
		}
	}
	private void plot_weekday(Graph.Graph graph)
	{
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


		graph.title_label = "Power consumption";
		graph.y_axis_label = "Energy (kWh)";
		graph.x_axis_label = "Week day";

		graph.min_y_point = 0;
		var ds = graph.create_data_set_bar();
		ds.set_color(0.4,0.5,0.3);

		graph.add_xticks(0.5, "Monday");
		graph.add_xticks(1.5, "Tuesday");
		graph.add_xticks(2.5, "Wednesday");
		graph.add_xticks(3.5, "Thursday");
		graph.add_xticks(4.5, "Friday");
		graph.add_xticks(5.5, "Saturday");
		graph.add_xticks(6.5, "Sunday");
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
	}

	/**
	 * Plotting graph
	 */
	void plot_graph(Graph.Graph graph)
	{
		bool do_average = false;
		bool do_bars    = false;
		bool do_points  = false;

		if(!do_bars) do_points = true;
		tstart = es.get_starting_datetime(tstart);
		tstop = es.get_stopping_datetime(tstop);

		double avg = es.get_average_energy(tstart, tstop);
		//double eng = es.get_energy(tstart, tstop);


		graph.title_label = "Power consumption";
		graph.y_axis_label = "Power (W)";
		graph.x_axis_label = "Time (HH:MM)";

		graph.min_y_point = 0;
		var ds = graph.create_data_set_area();
		ds.set_color(0.4,0.5,0.3);

		// if we need average.
		if(do_average)
		{
			var ds2 = new Graph.DataSetAverage(ds);
			graph.add_data_set(ds2);
			ds2.set_color(0.2,0.2,0.4);
		}
		if (do_bars)
		{
			var ds3 = graph.create_data_set_bar();
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
			graph.add_xticks((double)start.to_unix(),sa);

		}
	}
}
