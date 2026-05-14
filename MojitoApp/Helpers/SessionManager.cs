namespace MojitoApp.Helpers
{
    public static class SessionManager
    {
        public static int IdAngajat { get; private set; }
        public static string NumeComplet { get; private set; } = "";
        public static string Rol { get; private set; } = "";
        public static bool EsteAdmin => Rol == "admin";

        public static void SetAngajat(int id, string numeComplet, string rol)
        {
            IdAngajat = id;
            NumeComplet = numeComplet;
            Rol = rol;
        }

        public static void Clear()
        {
            IdAngajat = 0;
            NumeComplet = "";
            Rol = "";
        }
    }
}