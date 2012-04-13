class Status : Module
{
	private EnergyStorage es = null;
	public Status(EnergyStorage es)
	{
		this.es = es;
	}
	public override bool parse_arguments(string[] argv)
	{
		return true;
	}

	public override int execute()
	{
//		stdout.printf("Version:                      %s\n", VERSION);
		stdout.printf("Database file:                %s\n", es.filename);
		
		var length = es.get_data().length();
		stdout.printf("Logged points:                %u\n", length); 
		stdout.printf("Start date:                   %s\n", es.get_starting_datetime().format("%x %X"));
		stdout.printf("Stop date:                    %s\n", es.get_stopping_datetime().format("%x %X"));
		return 0;
	} 

}
