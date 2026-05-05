using Microsoft.Data.SqlClient;

namespace MojitoApp.Helpers
{
    public class DatabaseHelper
    {
        private static readonly string ConnectionString =
            "Server=ALEX_COMP1\\SQLEXPRESS;Database=MojitoDB;Integrated Security=True;TrustServerCertificate=True;";

        public static SqlConnection GetConnection()
        {
            return new SqlConnection(ConnectionString);
        }

        public static bool TestConnection()
        {
            try
            {
                using var conn = GetConnection();
                conn.Open();
                return true;
            }
            catch
            {
                return false;
            }
        }
    }
}