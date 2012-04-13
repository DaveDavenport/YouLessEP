using GLib;

/*******************************************************************
 * Statistics 
 ******************************************************************/
class Statistics : Module
{
	private EnergyStorage es = null;
	// 
	private DateTime tstart;
	private DateTime tstop;
	private bool do_weekdays = false;
	private bool do_day = false;
	private bool do_weeks = false;
	private bool do_months = false;

	// Constructor
	public Statistics ( EnergyStorage es )
	{
		this.es = es;
	} 

	public void print_help()
	{
		stdout.printf("""
Usage statistics:
ep statistics <options> <commands>

commands:
	day:            Shows the average power consumption for each hour of the day.
	weekdays:        Shows the average power consumption for each day of the week.
	weeks:          Shows the energy consumption for each week of the year.
	months:         Shows the energy consumption for each month of the year.

Options:
	--help, help	print this help message.
	range <start date> <end date>	limit the evaluated data to a certain range.

Example:
	    ep statistics range 4/11/12 4/12/12 day
    This will print the average power consumption for each hour on 11 April 2012.
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
				do_weekdays = true;
			}else if (argv[i] == "day") {
				do_day = true;
			}else if (argv[i] == "weeks") {
				do_weeks = true;
			}else if (argv[i] == "months") {
				do_months = true;
			} else {
				print_help();
				return false;
			}
		}
		return true;
	}

	public override int execute()
	{
		double avg = es.get_average_energy(tstart, tstop);
		double eng = es.get_energy(tstart, tstop);
		stdout.printf("Range:            %s --> %s\n", tstart.format("%d/%m/%Y - %H:%M"),tstop.format("%d/%m/%Y - %H:%M"));
		stdout.printf("Average power:    %8.02f W\n", avg);
		stdout.printf("Energy consumed:  %8.02f kWh\n", eng/1000.0);

		if(do_day) {
			statistics_day();
		}
		if(do_weekdays) {
			statistics_weekdays();
		}
		if(do_weeks) {
			weeks();
		}
		if(do_months) {
			months();
		}
		return 0;
	}
	private void months()
	{
		var start = tstart;
		var stop = start.add_minutes(-start.get_minute());
		stop = stop.add_hours(-stop.get_hour());
		stop = stop.add_days(-stop.get_day_of_week()+1);
		stop = stop.add_days(-stop.get_day_of_month()+1);
		stdout.printf("============ Months ===========\n");
		while(stop.compare(tstop)< 0)
		{
			start = stop;
			stop  = start.add_months(1);
			var num_days = stop.add_seconds(-1).get_day_of_month();

			var avg = es.get_average_energy(start,stop)*24*num_days/1000.0;
			stdout.printf("%2d                %8.02f kWh\n",start.get_month(),  avg);
		}
		stdout.printf("===============================\n");
	}
	private void weeks()
	{
		var start = tstart;
		var stop = start.add_minutes(-start.get_minute());
		stop = stop.add_hours(-stop.get_hour());
		stop = stop.add_days(-stop.get_day_of_week()+1);
		stdout.printf("============  Week  ===========\n");
		while(stop.compare(tstop)< 0)
		{
			start = stop;
			stop  = start.add_days(7);

			var avg = es.get_average_energy(start,stop)*24*7/1000.0;
			stdout.printf("%2d                %8.02f kWh\n",start.get_week_of_year(),  avg);
		}
		stdout.printf("===============================\n");
	}
	// Show average over day. 
	private void statistics_day()
	{
		double hour[24] = {0};
		int num_hour[24] = {0};

		stdout.printf("========== Day hours ==========\n");

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
		double total = 0;
		for(uint i = 0; i < 24; i++)
		{
			if(num_hour[i] > 0)
			{
				stdout.printf("%2u                %8.02f W\n", i, hour[i]/(double)num_hour[i]);
				total += hour[i]/(double)num_hour[i];
			}
		}
		stdout.printf("===============================\n");
		stdout.printf("Total:            %8.02f kWh\n", total/1e3);
	}

	/* show average in a week (per day) */
	void statistics_weekdays()
	{
		double week[7] = {0};
		int num_week[7] = {0};

		stdout.printf("========== Week days ==========\n");

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

		double total = 0;
		stdout.printf("Day:    Average:    Total:\n");
		for(uint i = 0; i < 7; i++)
		{
			stop = tstart.add_minutes(-start.get_minute());
			stop = stop.add_hours(-stop.get_hour());
			stop = stop.add_days(-stop.get_day_of_week()+1);
			if(num_week[i] > 0){
				total+= 24/1000.0*week[i]/(double)num_week[i];
				stdout.printf("%2u    %8.02f W  %8.02f kWh\n", i+1,
						week[i]/(double)num_week[i],
						24/1000.0*week[i]/(double)num_week[i]);
			}
			stop  = start.add_days(1);
		}
		stdout.printf("===============================\n");
		stdout.printf("Total:            %8.02f kWh\n", total);
	}
}
