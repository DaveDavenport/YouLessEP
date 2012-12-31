#if GUI
using GLib;
using Gtk;

class Plotting : Module
{
	private enum PlotType {
		POINTS, 		// Draw all the data points. (1 per minute).
		AVG_WEEKDAY,	// Draw the average usage per day in a week.
		AVG_HOURS,		// Draw the average usage per hour in a day.
		DAYS,			// Plot energy consumed per measured day.
		WEEKS,			// Plot energy consumed per measured week.
		MONTHS,			// Plot energy consumed per measured month.
		PATTERN,
		NUM_PLOT_TYPES	
	}

	// Backend pointer.
	private EnergyStorage es       = null;

	// config options.
	private bool do_svg 		   = false;
    private bool do_png            = false;
	private bool do_remove_avg     = false;
	private string output_filename = "output.svg";
	private uint output_width      = 800;
	private uint output_height     = 600;
	private bool do_average 	   = false;
	private Filter? filter         = null;
	private PlotType plot_type 	   = PlotType.POINTS;

	// Start stop
	private DateTime tstart;
	private DateTime tstop;

	// Constructor
	public Plotting(EnergyStorage es)
	{
		this.es = es;
	}

	// Help function.
	public void print_help()
	{
		stdout.printf(
"""
Usage plot:
ep plot <options> <commands>

				commands:
points:         Plot all the data points. (use in combination with range)
dayhours:       Shows the average power consumption for each hour of the day.
weekdays:        Shows the average power consumption for each day of the week.
weeks:	        Shows the energy consumption for each week of the year.
days:	        Shows the energy consumption for each day of the year.
months:         Shows the energy consumption for each month of the year.

Options:
    --help, help	                print this help message.
    range <start date> <end date>   Limit the evaluated data to a certain range.
    svg <filename>                  Outputs the graph to an SVG file.
    average                         Plot an average line.
    width <width in px>             The width of the output.
    height <height in px>           The height of the output.
    remove-avg:                     Tries to remove the 'base' usage and show just the 'spikes'. Only works for points plot.
	filter low high					Only shows points that are between low and high. Only works with remove-avg.

Example:
	ep plot days range 4/9/2012 4/16/2012 average output days.svg width 1024 height 600
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
			} else if (argv[i] == "weekdays") {
				plot_type = PlotType.AVG_WEEKDAY;	
			}else if (argv[i] == "points") {
				plot_type = PlotType.POINTS;
			}else if (argv[i] == "weeks") {
				plot_type = PlotType.WEEKS;
			}else if (argv[i] == "months") {
				plot_type = PlotType.MONTHS;
			}else if (argv[i] == "days") {
				plot_type = PlotType.DAYS;
			}else if (argv[i] == "dayhours") {
				plot_type = PlotType.AVG_HOURS;
			}else if (argv[i] == "remove-avg") {
				do_remove_avg = true;	
			}else if (argv[i] == "pattern") {
				plot_type = PlotType.PATTERN;	
			}else if (argv[i] == "png") {
				do_png = true;
				i++;
				if(i >= argv.length)
				{
					stdout.printf("Expected filename after png.\n");
					return false;
				}
				output_filename = argv[i];	
			}else if (argv[i] == "svg") {
				do_svg = true;	
				i++;
				if(i >= argv.length)
				{
					stdout.printf("Expected filename after svg.\n");
					return false;
				}
				output_filename = argv[i];	
			}else if (argv[i] == "width") {
				i++;
				if(i >= argv.length)
				{
					stdout.printf("Expected size after width.\n");
					return false;
				}
				output_width = (uint)uint64.parse(argv[i]);
				if(output_width < 100) {
					stdout.printf("The output should be atleast 100px width.\n");
					return false;
				}
			}else if (argv[i] == "height") {
				i++;
				if(i >= argv.length)
				{
					stdout.printf("Expected size after height.\n");
					return false;
				}
				output_height = (uint)uint64.parse(argv[i]);
				if(output_height < 100) {
					stdout.printf("The output should be atleast 100px heigh.\n");
					return false;
				}
			}else if (argv[i] == "filter") {
				i+=2;
				if(i >= argv.length)
				{
					stdout.printf("Expected lower and upper bound.\n");
					return false;
				}
				filter = new Filter((uint)uint64.parse(argv[i-1]), (uint)uint64.parse(argv[i]));
			}else if (argv[i] == "average") {
				do_average = true;	
			} else {
				print_help();
				return false;
			}
		}
		if(!(do_svg && do_png))
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
        Graph.PNG    png_plot = null;
		Graph.Graph  graph    = null;
		if(do_svg) 
		{
			svg_plot = new Graph.Svg();	
			graph = svg_plot.graph;
		} else if(do_png) 
		{
		    png_plot = new Graph.PNG();	
			graph = png_plot.graph;
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
			plot_weekdays(graph);
		}
		else if (plot_type ==  PlotType.WEEKS)
		{
			plot_weeks(graph);
		}
		else if (plot_type ==  PlotType.MONTHS)
		{
			plot_months(graph);
		}
		else if (plot_type ==  PlotType.DAYS)
		{
			plot_days(graph);
		}
		else if (plot_type ==  PlotType.AVG_HOURS)
		{
			plot_dayhours(graph);
		}
		else if (plot_type ==  PlotType.PATTERN)
		{
			pattern(graph, filter);
		}

		if(!(do_svg || do_png))
		{
			Gtk.Window win = new Gtk.Window();

			win.delete_event.connect((source) =>{
					Gtk.main_quit();
					return false;
					});
			// Set default size
			win.set_default_size((int)output_width, (int)output_height);
			win.add(widget);
			win.show_all();
			Gtk.main();
		}else if (do_svg) {
			svg_plot.output(output_filename, output_width, output_height);
		} else if (do_png) {
			png_plot.output(output_filename, output_width, output_height);
        }
        return 0;
	}
	private string week_format_plot(DateTime? t)
	{
		var start = t.add_minutes(-t.get_minute());
        start.add_days(-t.get_day_of_week()+1);
		var stop  = start.add_days(7);
		var avg = es.get_average_energy(start,stop)*24*7/1000.0;
        if (avg < 0) avg = 0;
		string retv = "x: %s (%s - %s)\ny: %.02f kWh".printf(
                start.format("%V"),start.format("%d/%m/%Y"),stop.format("%d/%m/%Y"), avg); 
        return retv;
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

		var ds3 = new Graph.DataSetBar<DateTime>();//graph.create_data_set_bar();
		graph.add_data_set(ds3);

		ds3.format_callback  = week_format_plot; 
		ds3.min_y_point = 0;
		ds3.set_color(0.5,0.2,0.2);
		while(stop.compare(tstop)< 0)
		{
			start = stop;
			stop  = start.add_days(7);

			stdout.printf("Range:            %s --> %s\n", start.format("%V %d/%m/%Y - %H:%M"),stop.format("%d/%m/%Y - %H:%M"));

            var value =es.get_average_energy(start,stop); 
			var avg = 0.0;
            if(value >= 0) avg = value*24*7/1000.0;
            
			stdout.printf("power: %.2f kWh\n", avg);
			ds3.add_point_value((double)stop.to_unix()-3.5*24*60*60, avg,start);
			graph.add_xticks((double)start.to_unix()+(3.5*24*60*60), start.format("%V"));
		}

		// if we need average.
		if(do_average)
		{
			var ds2 = new Graph.DataSetAverage<EnergyPoint?>(ds3);
			graph.add_data_set(ds2);
			ds2.set_color(0.2,0.2,0.4);
		}
	}
	private string day_format_plot(DateTime? t)
	{
		var start = t.add_minutes(-t.get_minute());
		var stop  = start.add_days(1);
		var avg = es.get_average_energy(start,stop)*24/1000.0;
        if (avg < 0) avg = 0;
		string retv = "x: %s\ny: %.02f kWh".printf(t.format("(%A) %j (%d/%m/%Y)"), avg); 
		return retv;
	}
	private void plot_days(Graph.Graph graph)
	{
		var start = tstart;
		var stop = start.add_minutes(-start.get_minute());
		stop = stop.add_hours(-stop.get_hour());

		graph.title_label = "Power consumption";
		graph.y_axis_label = "Energy (kWh)";
		graph.x_axis_label = "Day";

		var ds3 = new Graph.DataSetBar<DateTime>();//graph.create_data_set_bar();
		graph.add_data_set(ds3);
		ds3.set_color(0.2,0.5,0.2);
		// Graph 0 point  to 0
		ds3.min_y_point = 0;


		ds3.format_callback  = day_format_plot; 


		graph.add_xticks((double)stop.to_unix(),""); 
		while(stop.compare(tstop)< 0)
		{
			start = stop;
			stop  = start.add_days(1);

			var day = start.get_day_of_year();

			stdout.printf("Range:%u            %s --> %s\n",day, start.format("%B %d/%m/%Y - %H:%M"),stop.format("%d/%m/%Y - %H:%M"));
			var avg = es.get_average_energy(start,stop)*24/1000.0;

            if(avg <0) avg = 0;

			stdout.printf("power: %.2f kWh\n", avg);
			ds3.add_point_value((double)start.to_unix()+(0.5*24*60*60), avg, start);
			graph.add_xticks((double)start.to_unix()+(0.5*24*60*60), "%03d".printf(day));
		}
		graph.add_xticks((double)stop.to_unix(),""); 
		// if we need average.
		if(do_average)
		{
			var ds2 = new Graph.DataSetAverage<EnergyPoint?>(ds3);
			graph.add_data_set(ds2);
			ds2.set_color(0.2,0.2,0.4);
		}
	}
	private string month_format_plot(DateTime? t)
	{
		var start = t;
		var stop  = start.add_months(1);
		var avg = es.get_average_energy(start,stop)*(stop.difference(start)/(3600*1000*1000.0))/1000.0;
        if (avg < 0) avg = 0;
		string retv = "x: %s \ny: %.02f kWh".printf(
                start.format("%B"), avg); 
        return retv;
	}
	private void plot_months(Graph.Graph graph)
	{
		var start = tstart;
		var stop = start.add_minutes(-start.get_minute());
		stop = stop.add_hours(-stop.get_hour());
		stop = stop.add_days(-stop.get_day_of_month()+1);

		graph.title_label = "Power consumption";
		graph.y_axis_label = "Energy (kWh)";
		graph.x_axis_label = "Month";

		var ds3 = new Graph.DataSetBar<DateTime>();//graph.create_data_set_bar();
		graph.add_data_set(ds3);
		ds3.set_color(0.5,0.2,0.2);
		// Graph 0 point  to 0
		ds3.min_y_point = 0;
		
        ds3.format_callback  = month_format_plot; 

		graph.add_xticks((double)stop.to_unix(),""); 
		while(stop.compare(tstop)< 0)
		{
			start = stop;
			stop  = start.add_months(1);

			var num_days = stop.add_seconds(-1).get_day_of_month();

			stdout.printf("Range:%u            %s --> %s\n",num_days, start.format("%B %d/%m/%Y - %H:%M"),stop.format("%d/%m/%Y - %H:%M"));
			var avg = es.get_average_energy(start,stop)*num_days*24/1000.0;
            if(avg < 0) avg = 0.0;

			stdout.printf("power: %.2f kWh\n", avg);
			ds3.add_point_value((double)start.to_unix()+(num_days*0.5*24*60*60), avg,start);
			graph.add_xticks((double)start.to_unix()+(num_days*0.5*24*60*60), start.format("%B"));
		}
		graph.add_xticks((double)stop.to_unix(),""); 
		// if we need average.
		if(do_average)
		{
			var ds2 = new Graph.DataSetAverage<EnergyPoint?>(ds3);
			graph.add_data_set(ds2);
			ds2.set_color(0.2,0.2,0.4);
		}
	}
	private void plot_weekdays(Graph.Graph graph)
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

            var val  = es.get_average_energy(start, stop);
            if(val >= 0) {
                week[d-1] += val;
                num_week[d-1]++;
            }

		}


		graph.title_label = "Power consumption";
		graph.y_axis_label = "Energy (kWh)";
		graph.x_axis_label = "Week day";

		graph.min_y_point = 0;
		var ds = new Graph.DataSetBar<EnergyPoint?>();//graph.create_data_set_bar();
		graph.add_data_set(ds);
		ds.set_color(0.4,0.5,0.3);
		ds.min_y_point = 0;
		graph.add_xticks(0.0, "");
		graph.add_xticks(0.5, "Monday");
		graph.add_xticks(1.5, "Tuesday");
		graph.add_xticks(2.5, "Wednesday");
		graph.add_xticks(3.5, "Thursday");
		graph.add_xticks(4.5, "Friday");
		graph.add_xticks(5.5, "Saturday");
		graph.add_xticks(6.5, "Sunday");
		graph.add_xticks(7.0, "");
		//		ds.add_point(0, 0);
		for(uint i = 0; i < 7; i++)
		{
			if(num_week[i] > 0)
			{
				stdout.printf("%u %f %i\n",i, 24/1000.0*week[i]/(double)num_week[i], num_week[i]);
				ds.add_point(i+0.5, 
						24/1000.0*week[i]/(double)num_week[i]);
			}else{
				ds.add_point(i+0.5, 0);	
			}
		}
		// if we need average.
		if(do_average)
		{
			var ds2 = new Graph.DataSetAverage<EnergyPoint?>(ds);
			graph.add_data_set(ds2);
			ds2.set_color(0.2,0.2,0.4);
		}
	}
	private void plot_dayhours(Graph.Graph graph)
	{
		double hour[24] = {0};
		int num_hour[24] = {0};

		var start = tstart;
		var stop = start.add_minutes(-start.get_minute());
		while(stop.compare(tstop)< 0)
		{
			start = stop;
			int d = start.get_hour();
			stop  = start.add_hours(1);

            var val = es.get_average_energy(start, stop);
            if(val >= 0) {
                hour[d] += es.get_average_energy(start, stop);
                num_hour[d]++;
            }

		}


		graph.title_label = "Power consumption";
		graph.y_axis_label = "Energy (kWh)";
		graph.x_axis_label = "Hour";

		graph.min_y_point = 0;
		var ds = new Graph.DataSetBar<EnergyPoint?>();//graph.create_data_set_bar();
		graph.add_data_set(ds);
		ds.set_color(0.4,0.5,0.3);
		ds.min_y_point = 0;
		// Add X-grid points. 
		graph.add_xticks(0.0, "");
		for(uint i = 0 ; i < 24; i++)
		{
			graph.add_xticks(0.5+i, "%2u".printf(i));
		}
		graph.add_xticks(24.0, "");

		for(uint i = 0; i < 24; i++)
		{
			if(num_hour[i] > 0)
			{
				stdout.printf("%u %f %i\n",i, 24/1000.0*hour[i]/(double)num_hour[i], num_hour[i]);
				ds.add_point(i+0.5, 
						1/1000.0*hour[i]/(double)num_hour[i]);
			}else{
				ds.add_point(i+0.5, 0);	
			}
		}
		// if we need average.
		if(do_average)
		{
			var ds2 = new Graph.DataSetAverage<EnergyPoint?>(ds);
			graph.add_data_set(ds2);
			ds2.set_color(0.2,0.2,0.4);
		}
	}

	/**
	 * Plotting graph
	 */
	void plot_graph(Graph.Graph graph)
	{
		//		bool do_bars    = false;
		bool do_points  = true;

		//		if(!do_bars) do_points = true;
		tstart = es.get_starting_datetime(tstart);
		tstop = es.get_stopping_datetime(tstop);

		double avg = es.get_average_energy(tstart, tstop);
		//double eng = es.get_energy(tstart, tstop);


		graph.title_label = "Power consumption";
		graph.y_axis_label = "Power (W)";
		graph.x_axis_label = "Time (HH:MM)";

		graph.min_y_point = 0;
		var ds = new Graph.DataSetArea<EnergyPoint?>();
		graph.add_data_set(ds);
		ds.set_color(0.4,0.5,0.3);
		/*
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
		 */
		// add zero point.
		if(do_points)
		{
			var ds3 = new Graph.DataSetLine<EnergyPoint?>();
			graph.add_data_set(ds3);
			(ds3 as Graph.DataSetLine).dots= false;
			ds3.set_color(1.0,0.0,0.0);
			if(do_remove_avg)
			{
				graph.add_data_set(ds3);
			}
			double avr = avg;
			uint iter = 0;
			double average[8] = {0};
			average[0] = avg;
			ds.add_point((double)tstart.to_unix(), 0);
			
			if(do_remove_avg)
			{
				ds3.add_point((double)tstart.to_unix(), avg);
				for(int i = 0; i < 8; i++) {
					average[i] = avg;
				}
			}
			foreach ( EnergyPoint ep in es.get_data(tstart, tstop))
			{
				if(do_remove_avg)
				{
					if(ep.power < (1.5*avr)) {	
						average[iter++%8] = ep.power;
					}else average[iter++%8] = avr;
					avr = 0;
					for(int i = 0; i < 8; i++) {
						avr+=average[i]/8.0;
					}
					double value = double.min(avr, ep.power);
					ds3.add_point((double)ep.time, value); 
					if(filter == null || filter.check(ep.power-value))
					{
						ds.add_point((double)ep.time, ep.power-value);
					}
					else
						ds.add_point((double)ep.time, 0);
				}else{
					ds.add_point((double)ep.time, ep.power);
				}
			}
		}
		// if we need average.
		if(do_average)
		{
			var ds2 = new Graph.DataSetAverage<EnergyPoint?>(ds);
			graph.add_data_set(ds2);
			ds2.set_color(0.2,0.2,0.4);
			ds2.average = avg;
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
	void pattern(Graph.Graph graph, Filter filter)
	{
		double avg = es.get_average_energy(tstart, tstop);
		stdout.printf("========== Pattern ==========\n");

		double avr = avg;
		uint iter = 0;
		double average[8] = {0};

		for(int i = 0; i < 8; i++) {
			average[i] = avg;
		}
		EnergyPoint? pp = null;
		bool prev = false;
		int max_val = 0;
		GLib.HashTable<int, int> g = new GLib.HashTable<int, int>(GLib.direct_hash, GLib.direct_equal);
		foreach ( EnergyPoint ep in es.get_data(tstart, tstop))
		{
			if(ep.power < (1.5*avr)) {	
				average[iter++%8] = ep.power;
			}else average[iter++%8] = avr;
			avr = 0;
			for(int i = 0; i < 8; i++) {
				avr+=average[i]/8.0;
			}
			double value = double.min(avr, ep.power);
			if(filter.check(ep.power - value))
			{
				if(!prev)
				{
					if(pp != null)
					{
						var diff = (ep.time - pp.time);
						diff = diff - diff%300;
						stdout.printf("%f\n", diff);
						int items = g.lookup((int)diff);
						{
							max_val = int.max(items+1, max_val);
							g.insert((int)diff,items+1); 
						}
					}
					pp = ep;
					prev = true;
				}
			}
			else {
				prev = false;
			}
		}
		var eps = g.get_keys();
		eps.sort((a, b) => {
			return a-b;
		});
		var ds = new Graph.DataSetBar<EnergyPoint?>();//graph.create_data_set_bar();
		graph.add_data_set(ds);
		ds.set_color(0.4,0.5,0.3);
		ds.min_y_point = 0;
		graph.add_data_set(ds);
		ds.add_point(0, 0);
		foreach(int key in eps) 
		{
			int value = g.get(key);
			if(key > 0 && max_val/5 < value){  
				stdout.printf("%i %i\n", key,value); 
				ds.add_point((double)key, (double) value); 
			}
		}

	}
}
#endif
