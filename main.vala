using GLib;


class Filter
{
	private uint under = 0;
	private uint upper = uint.MAX;

	public Filter(uint under, uint upper)
	{
		this.under = under;
		this.upper = upper;
	}
	public bool check(double power)
	{
		if(power > under && power < upper)
			return true;
		return false;
	}
}

/* Base module Class. */
abstract class Module 
{

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
	/* Get user data dir */
	var udd = GLib.Environment.get_user_data_dir();
	var path = GLib.Path.build_filename(udd, "es.sqlite3");
	EnergyStorage es = new EnergyStorage(path);

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
		 * Status
		 */
		else if (argv[1] == "status")
		{
			module = new Status(es);
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
		stdout.printf("The following modules are supported: import, plot, statistics, status.\n");
		stdout.printf("Use ep <module> help for more help.\n");
		return 1;
	}
}
