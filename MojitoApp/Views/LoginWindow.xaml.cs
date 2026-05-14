using System.Security.Cryptography;
using System.Text;
using System.Windows;
using System.Windows.Controls;
using Microsoft.Data.SqlClient;
using MojitoApp.Helpers;

namespace MojitoApp.Views
{
    public partial class LoginWindow : Window
    {
        private int _incercari = 0;

        public LoginWindow()
        {
            InitializeComponent();
        }

        private void btnLogin_Click(object sender, RoutedEventArgs e)
        {
            if (_incercari >= 3)
            {
                txtEroare.Text = "Cont blocat! Prea multe încercări eșuate.";
                txtEroare.Visibility = Visibility.Visible;
                btnLogin.IsEnabled = false;
                return;
            }

            string username = txtUsername.Text.Trim();
            string parola = HashParola(txtParola.Password);
            
            if (string.IsNullOrEmpty(username) || string.IsNullOrEmpty(txtParola.Password))
            {
                txtEroare.Text = "Introduceți username și parolă!";
                txtEroare.Visibility = Visibility.Visible;
                return;
            }

            if (VerificaCredentiale(username, parola))
            {
                MainWindow main = new MainWindow();
                main.Show();
                this.Close();
            }
            else
            {
                _incercari++;
                txtEroare.Text = $"Credențiale greșite! Încercări rămase: {3 - _incercari}";
                txtEroare.Visibility = Visibility.Visible;
                txtParola.Clear();
            }
        }

        private bool VerificaCredentiale(string username, string parolaHash)
        {
            try
            {
                using var conn = DatabaseHelper.GetConnection();
                conn.Open();
                string query = @"SELECT id, nume, prenume, rol FROM Angajati 
                        WHERE username=@u AND parola_hash=@p";
                using var cmd = new SqlCommand(query, conn);
                cmd.Parameters.AddWithValue("@u", username);
                cmd.Parameters.AddWithValue("@p", parolaHash);
                using var reader = cmd.ExecuteReader();
                if (reader.Read())
                {
                    SessionManager.SetAngajat(
                        reader.GetInt32(0),
                        reader.GetString(1) + " " + reader.GetString(2),
                        reader.GetString(3)
                    );
                    return true;
                }
                return false;
            }
            catch { return false; }
        }

        private string HashParola(string parola)
        {
            using var sha = SHA256.Create();
            byte[] bytes = sha.ComputeHash(Encoding.UTF8.GetBytes(parola));
            return Convert.ToHexString(bytes).ToLower();
        }
    }
}