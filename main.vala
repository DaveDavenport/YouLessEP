using GLib;

/* Base module Class. */
abstract class Module 
{

	public abstract void print_help();
	public abstract bool parse_arguments(string[] argv);
	public abstract int execute();
}


// Helper functions.

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


/* input */
int main (string[] argv)
{
	EnergyStorage es = new EnergyStorage("es.sqlite3");
	if(argv.length > 1)
	{
		Module module = null;
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
		else if (argv[1] == "plot")
		{
			module = new Plotting(es);
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
			stdout.printf("'%s' is an invalid module.", argv[1]);
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
		stdout.printf("Usage: %s <module> <options>\n\n", argv[0]);	
		stdout.printf("The following modules are supported: import, plot, statistics.\n");
		stdout.printf("Use ep <module> help for more help.\n");
		return 1;
	}
}
