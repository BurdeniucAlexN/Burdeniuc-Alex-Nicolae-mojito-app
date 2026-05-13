using System.Security.Cryptography;
using System.Text;
using System.Windows;
using System.Windows.Controls;
using Microsoft.Data.SqlClient;
using MojitoApp.Helpers;

namespace MojitoApp.Views
{
    public class AngajatDisplay
    {
        public int Id { get; set; }
        public string Nume { get; set; } = "";
        public string Prenume { get; set; } = "";
        public string Username { get; set; } = "";
        public string Rol { get; set; } = "";
        public string RolColor => Rol == "admin" ? "#C8A96E" : "#CCCCCC";
    }

    public partial class AngajatiPage : Page
    {
        public AngajatiPage()
        {
            InitializeComponent();
            IncarcaAngajati();
        }

        private void IncarcaAngajati()
        {
            var lista = new List<AngajatDisplay>();
            using var conn = DatabaseHelper.GetConnection();
            conn.Open();
            string query = "SELECT id, nume, prenume, username, rol FROM Angajati ORDER BY id";
            using var cmd = new SqlCommand(query, conn);
            using var reader = cmd.ExecuteReader();
            while (reader.Read())
            {
                lista.Add(new AngajatDisplay
                {
                    Id = reader.GetInt32(0),
                    Nume = reader.GetString(1),
                    Prenume = reader.GetString(2),
                    Username = reader.GetString(3),
                    Rol = reader.GetString(4)
                });
            }
            listAngajati.ItemsSource = lista;
        }

        private void btnAdaugaAngajat_Click(object sender, RoutedEventArgs e)
        {
            txtEroareAngajat.Visibility = Visibility.Collapsed;

            if (string.IsNullOrWhiteSpace(txtNume.Text) ||
                string.IsNullOrWhiteSpace(txtPrenume.Text) ||
                string.IsNullOrWhiteSpace(txtUsername.Text) ||
                string.IsNullOrWhiteSpace(txtParola.Password))
            {
                txtEroareAngajat.Text = "Completați toate câmpurile!";
                txtEroareAngajat.Visibility = Visibility.Visible;
                return;
            }

            string rol = (cmbRol.SelectedItem as ComboBoxItem)?.Content?.ToString() ?? "chelner";
            string parolaHash = HashParola(txtParola.Password);

            try
            {
                using var conn = DatabaseHelper.GetConnection();
                conn.Open();
                string query = @"INSERT INTO Angajati (nume, prenume, rol, username, parola_hash)
                                VALUES (@n, @p, @r, @u, @ph)";
                using var cmd = new SqlCommand(query, conn);
                cmd.Parameters.AddWithValue("@n", txtNume.Text.Trim());
                cmd.Parameters.AddWithValue("@p", txtPrenume.Text.Trim());
                cmd.Parameters.AddWithValue("@r", rol);
                cmd.Parameters.AddWithValue("@u", txtUsername.Text.Trim());
                cmd.Parameters.AddWithValue("@ph", parolaHash);
                cmd.ExecuteNonQuery();

                MessageBox.Show($"✅ Angajat {txtNume.Text} {txtPrenume.Text} adăugat!",
                    "Succes", MessageBoxButton.OK, MessageBoxImage.Information);

                txtNume.Clear(); txtPrenume.Clear();
                txtUsername.Clear(); txtParola.Clear();
                IncarcaAngajati();
            }
            catch (Exception ex)
            {
                txtEroareAngajat.Text = ex.Message.Contains("UNIQUE") ?
                    "Username există deja!" : "Eroare la salvare!";
                txtEroareAngajat.Visibility = Visibility.Visible;
            }
        }

        private void btnDezactiveaza_Click(object sender, RoutedEventArgs e)
        {
            if (listAngajati.SelectedItem is not AngajatDisplay angajat)
            {
                MessageBox.Show("Selectați un angajat!", "Atenție",
                    MessageBoxButton.OK, MessageBoxImage.Warning);
                return;
            }

            if (angajat.Username == "admin")
            {
                MessageBox.Show("Nu puteți dezactiva contul admin!", "Atenție",
                    MessageBoxButton.OK, MessageBoxImage.Warning);
                return;
            }

            var confirmare = MessageBox.Show(
                $"Dezactivați angajatul {angajat.Nume} {angajat.Prenume}?",
                "Confirmare", MessageBoxButton.YesNo, MessageBoxImage.Question);

            if (confirmare == MessageBoxResult.Yes)
            {
                using var conn = DatabaseHelper.GetConnection();
                conn.Open();
                string query = "DELETE FROM Angajati WHERE id = @id";
                using var cmd = new SqlCommand(query, conn);
                cmd.Parameters.AddWithValue("@id", angajat.Id);
                cmd.ExecuteNonQuery();

                MessageBox.Show("Angajat eliminat!", "Succes",
                    MessageBoxButton.OK, MessageBoxImage.Information);
                IncarcaAngajati();
            }
        }

        private string HashParola(string parola)
        {
            using var sha = SHA256.Create();
            byte[] bytes = sha.ComputeHash(Encoding.UTF8.GetBytes(parola));
            return Convert.ToHexString(bytes).ToLower();
        }
    }
}