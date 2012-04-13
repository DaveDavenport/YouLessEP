using GLib;

/**
 * This module takes care of importing files into the DB
 */
class Import : Module
{
	private EnergyStorage es = null;
	private List<string> files;
	// Constructor
	public Import (EnergyStorage es)
	{
		this.es = es;
	}
	
	public void print_help()
	{
		stdout.printf("""
Usage import:
ep import <list of files>

This module imports data points from json file(s) into the database.
The current importer only supports the data files containing minute samples 
produced by the YouLess energy meter. 
Duplicate points are automatically ignored.

Options:
	--help, help	print this help message.
""");

	}

	public override bool parse_arguments(string[] argv)
	{
		if(argv.length == 0)
		{
			print_help();
			return false;
		}
		for(uint i =0; i < argv.length; i++)
		{
			if(argv[i] == "help" || argv[i] == "--help")
			{
				print_help();
				return false;
	
			}else{
				files.prepend(argv[i]);
			}
		}
		files.reverse();
		return true;
	}

	/**
	 * Importing files.
	 */
	public override int execute()
	{
		uint total = 0;
		es.start_transaction();
		foreach(var file in files)
		{
			stdout.printf("Importing file: '%s': ", file);
			try {
				uint retv = es.parse_from_json(file);
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
		return 0;
	}
}
