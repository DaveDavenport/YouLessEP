using GLib;


class Pricing 
{
    private EnergyStorage es = null;

    // Pricing:
    private double low_price = 0.0f;
    private double high_price = 0.0f;

    public Pricing ( EnergyStorage es)
    {
        this.es = es;
    }


    public double calculate_price(DateTime start, DateTime stop)
    {
        double price = 0.0;

        


        return price;
    }

}
