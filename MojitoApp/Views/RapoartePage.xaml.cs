using System.Windows;
using System.Windows.Controls;
using Microsoft.Data.SqlClient;
using MojitoApp.Helpers;

namespace MojitoApp.Views
{
    public class VanzareDisplay
    {
        public int Id { get; set; }
        public string DataOra { get; set; } = "";
        public string NumeAngajat { get; set; } = "";
        public int NrProduse { get; set; }
        public decimal Total { get; set; }
    }

    public class TopProdusDisplay
    {
        public int Pozitie { get; set; }
        public string Nume { get; set; } = "";
        public int CantitateVanduta { get; set; }
        public decimal TotalMDL { get; set; }
    }

    public class DetaliiVanzareDisplay
    {
        public string NumeProdus { get; set; } = "";
        public int Cantitate { get; set; }
        public decimal PretUnitar { get; set; }
        public decimal Subtotal => PretUnitar * Cantitate;
    }

    public partial class RapoartePage : Page
    {
        public RapoartePage()
        {
            InitializeComponent();
            dpDeLa.SelectedDate = DateTime.Today;
            dpPanaLa.SelectedDate = DateTime.Today;
            IncarcaVanzariAzi();
            IncarcaTop();
        }

        private void btnAzi_Click(object sender, RoutedEventArgs e)
        {
            dpDeLa.SelectedDate = DateTime.Today;
            dpPanaLa.SelectedDate = DateTime.Today;
            IncarcaVanzariAzi();
        }

        private void btnFiltra_Click(object sender, RoutedEventArgs e)
        {
            if (dpDeLa.SelectedDate == null || dpPanaLa.SelectedDate == null)
            {
                MessageBox.Show("Selectați perioada!", "Atenție",
                    MessageBoxButton.OK, MessageBoxImage.Warning);
                return;
            }
            IncarcaVanzari(dpDeLa.SelectedDate.Value, dpPanaLa.SelectedDate.Value);
        }

        private void IncarcaVanzariAzi()
        {
            IncarcaVanzari(DateTime.Today, DateTime.Today);
        }

        private void IncarcaVanzari(DateTime deLa, DateTime panaLa)
        {
            var lista = new List<VanzareDisplay>();
            using var conn = DatabaseHelper.GetConnection();
            conn.Open();

            string query = @"SELECT V.id, V.data_ora, A.nume + ' ' + A.prenume,
                            COUNT(DV.id) AS nr_produse, V.total
                            FROM Vanzari V
                            INNER JOIN Angajati A ON V.id_angajat = A.id
                            LEFT JOIN Detalii_Vanzari DV ON V.id = DV.id_vanzare
                            WHERE CAST(V.data_ora AS DATE) BETWEEN @d1 AND @d2
                            GROUP BY V.id, V.data_ora, A.nume, A.prenume, V.total
                            ORDER BY V.data_ora DESC";

            using var cmd = new SqlCommand(query, conn);
            cmd.Parameters.AddWithValue("@d1", deLa.Date);
            cmd.Parameters.AddWithValue("@d2", panaLa.Date);
            using var reader = cmd.ExecuteReader();

            while (reader.Read())
            {
                lista.Add(new VanzareDisplay
                {
                    Id = reader.GetInt32(0),
                    DataOra = reader.GetDateTime(1).ToString("dd.MM.yyyy HH:mm"),
                    NumeAngajat = reader.GetString(2),
                    NrProduse = reader.GetInt32(3),
                    Total = reader.GetDecimal(4)
                });
            }

            listVanzari.ItemsSource = lista;
            decimal totalPerioda = lista.Sum(v => v.Total);
            txtTotalPerioda.Text = $"{totalPerioda:F2} MDL";
            txtNrComenzi.Text = $"Comenzi: {lista.Count}";
        }

        private void btnActualizeazaTop_Click(object sender, RoutedEventArgs e)
        {
            IncarcaTop();
        }

        private void IncarcaTop()
        {
            var lista = new List<TopProdusDisplay>();
            using var conn = DatabaseHelper.GetConnection();
            conn.Open();

            string query = @"SELECT TOP 20 P.nume,
                            SUM(DV.cantitate) AS total_cantitate,
                            SUM(DV.cantitate * DV.pret_unitar) AS total_mdl
                            FROM Detalii_Vanzari DV
                            INNER JOIN Produse P ON DV.id_produs = P.id
                            GROUP BY P.id, P.nume
                            ORDER BY total_cantitate DESC";

            using var cmd = new SqlCommand(query, conn);
            using var reader = cmd.ExecuteReader();
            int pozitie = 1;

            while (reader.Read())
            {
                lista.Add(new TopProdusDisplay
                {
                    Pozitie = pozitie++,
                    Nume = reader.GetString(0),
                    CantitateVanduta = reader.GetInt32(1),
                    TotalMDL = reader.GetDecimal(2)
                });
            }

            listTop.ItemsSource = lista;
        }

        private void btnCautaComanda_Click(object sender, RoutedEventArgs e)
        {
            if (!int.TryParse(txtIdComanda.Text, out int idComanda))
            {
                MessageBox.Show("Introduceți un ID valid!", "Atenție",
                    MessageBoxButton.OK, MessageBoxImage.Warning);
                return;
            }

            var lista = new List<DetaliiVanzareDisplay>();
            using var conn = DatabaseHelper.GetConnection();
            conn.Open();

            string query = @"SELECT P.nume, DV.cantitate, DV.pret_unitar
                            FROM Detalii_Vanzari DV
                            INNER JOIN Produse P ON DV.id_produs = P.id
                            WHERE DV.id_vanzare = @id
                            ORDER BY P.nume";

            using var cmd = new SqlCommand(query, conn);
            cmd.Parameters.AddWithValue("@id", idComanda);
            using var reader = cmd.ExecuteReader();

            while (reader.Read())
            {
                lista.Add(new DetaliiVanzareDisplay
                {
                    NumeProdus = reader.GetString(0),
                    Cantitate = reader.GetInt32(1),
                    PretUnitar = reader.GetDecimal(2)
                });
            }

            if (lista.Count == 0)
                MessageBox.Show($"Comanda #{idComanda} nu a fost găsită!", "Info",
                    MessageBoxButton.OK, MessageBoxImage.Information);

            listDetalii.ItemsSource = lista;
        }
    }
}