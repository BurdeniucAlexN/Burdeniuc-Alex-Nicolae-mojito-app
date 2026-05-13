using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using Microsoft.Data.SqlClient;
using MojitoApp.Helpers;
using MojitoApp.Models;
using MojitoApp.Services;

namespace MojitoApp.Views
{
    public class StocDisplay
    {
        public int Id { get; set; }
        public int IdIngredient { get; set; }
        public string NumeIngredient { get; set; } = "";
        public decimal CantitateDisponibila { get; set; }
        public decimal CantitateMinima { get; set; }
        public string UnitateMasura { get; set; } = "";
        public string Status => CantitateDisponibila <= CantitateMinima ? "⚠ CRITIC" : "✓ OK";
        public string StatusColor => CantitateDisponibila <= CantitateMinima ? "#E74C3C" : "#2ECC71";
    }

    public class StocManualDisplay
    {
        public int Id { get; set; }
        public string NumeProdus { get; set; } = "";
        public string Unitate { get; set; } = "";
        public decimal Cantitate { get; set; }
        public decimal CantitateMinima { get; set; }
        public string Status => Cantitate <= CantitateMinima ? "⚠ CRITIC" : "✓ OK";
        public string StatusColor => Cantitate <= CantitateMinima ? "#E74C3C" : "#2ECC71";
    }
    public class ImportStocItem
    {
        public int IdIngredient { get; set; }
        public string Nume { get; set; } = "";
        public decimal StocCurent { get; set; }
        public decimal CantitateAdaugata { get; set; }
        public decimal StocNou => StocCurent + CantitateAdaugata;
        public string Unitate { get; set; } = "";
        public string Status { get; set; } = "";
        public string StatusColor => Status == "✓ Găsit" ? "#2ECC71" : "#E74C3C";
    }
    public partial class StocuriPage : Page
    {
        private readonly StocService _stocService = new();
        private StocDisplay? _stocSelectat = null;
        private StocManualDisplay? _stocManualSelectat = null;
        private List<ImportStocItem> _importItems = new();

        private void btnProceseazaStoc_Click(object sender, RoutedEventArgs e)
        {
            _importItems = new List<ImportStocItem>();
            string input = txtImportStoc.Text.Trim();

            if (string.IsNullOrWhiteSpace(input))
            {
                MessageBox.Show("Introduceți lista!", "Atenție",
                    MessageBoxButton.OK, MessageBoxImage.Warning);
                return;
            }

            string[] linii = input.Split('\n',
                StringSplitOptions.RemoveEmptyEntries |
                StringSplitOptions.TrimEntries);

            foreach (string linie in linii)
            {
                if (string.IsNullOrWhiteSpace(linie)) continue;

                string[] parti = linie.Trim().Split(' ');
                decimal cantitate = 0;
                string numeIngredient = linie.Trim();

                if (parti.Length > 1 && decimal.TryParse(parti[^1],
                    System.Globalization.NumberStyles.Any,
                    System.Globalization.CultureInfo.InvariantCulture,
                    out decimal cant))
                {
                    cantitate = cant;
                    numeIngredient = string.Join(" ", parti[..^1]).Trim();
                }

                var ingredient = CautaIngredient(numeIngredient);

                if (ingredient != null)
                {
                    _importItems.Add(new ImportStocItem
                    {
                        IdIngredient = ingredient.Value.id,
                        Nume = ingredient.Value.nume,
                        StocCurent = ingredient.Value.stocCurent,
                        CantitateAdaugata = cantitate,
                        Unitate = ingredient.Value.unitate,
                        Status = "✓ Găsit"
                    });
                }
                else
                {
                    _importItems.Add(new ImportStocItem
                    {
                        IdIngredient = -1,
                        Nume = numeIngredient,
                        StocCurent = 0,
                        CantitateAdaugata = cantitate,
                        Unitate = "-",
                        Status = "✗ Negăsit"
                    });
                }
            }

            listImportStoc.ItemsSource = _importItems;
        }

        private (int id, string nume, decimal stocCurent, string unitate)? CautaIngredient(string numeCautat)
        {
            try
            {
                using var conn = DatabaseHelper.GetConnection();
                conn.Open();

                // Cautare exacta
                string query = @"SELECT TOP 1 I.id, I.nume, S.cantitate_disponibila, I.unitate_masura
                        FROM Ingrediente I
                        INNER JOIN Stocuri S ON I.id = S.id_ingredient
                        WHERE LOWER(I.nume) = LOWER(@n)";
                using var cmd = new SqlCommand(query, conn);
                cmd.Parameters.AddWithValue("@n", numeCautat);
                using var reader = cmd.ExecuteReader();

                if (reader.Read())
                    return (reader.GetInt32(0), reader.GetString(1),
                            reader.GetDecimal(2), reader.GetString(3));

                reader.Close();

                // Cautare partiala
                string query2 = @"SELECT TOP 1 I.id, I.nume, S.cantitate_disponibila, I.unitate_masura
                         FROM Ingrediente I
                         INNER JOIN Stocuri S ON I.id = S.id_ingredient
                         WHERE LOWER(I.nume) LIKE LOWER(@n)
                         ORDER BY LEN(I.nume) ASC";
                using var cmd2 = new SqlCommand(query2, conn);
                cmd2.Parameters.AddWithValue("@n", $"%{numeCautat}%");
                using var reader2 = cmd2.ExecuteReader();

                if (reader2.Read())
                    return (reader2.GetInt32(0), reader2.GetString(1),
                            reader2.GetDecimal(2), reader2.GetString(3));

                return null;
            }
            catch { return null; }
        }

        private void btnConfirmaStoc_Click(object sender, RoutedEventArgs e)
        {
            var gasite = _importItems.Where(i => i.IdIngredient > 0).ToList();

            if (gasite.Count == 0)
            {
                MessageBox.Show("Niciun ingredient găsit!", "Atenție",
                    MessageBoxButton.OK, MessageBoxImage.Warning);
                return;
            }

            var confirmare = MessageBox.Show(
                $"Actualizați stocul pentru {gasite.Count} ingrediente?",
                "Confirmare", MessageBoxButton.YesNo, MessageBoxImage.Question);

            if (confirmare == MessageBoxResult.Yes)
            {
                using var conn = DatabaseHelper.GetConnection();
                conn.Open();

                foreach (var item in gasite)
                {
                    string query = @"UPDATE Stocuri 
                            SET cantitate_disponibila = cantitate_disponibila + @c
                            WHERE id_ingredient = @i";
                    using var cmd = new SqlCommand(query, conn);
                    cmd.Parameters.AddWithValue("@c", item.CantitateAdaugata);
                    cmd.Parameters.AddWithValue("@i", item.IdIngredient);
                    cmd.ExecuteNonQuery();
                }

                MessageBox.Show($"✅ Stoc actualizat pentru {gasite.Count} ingrediente!",
                    "Succes", MessageBoxButton.OK, MessageBoxImage.Information);

                txtImportStoc.Clear();
                _importItems.Clear();
                listImportStoc.ItemsSource = null;
                IncarcaDate();
            }
        }

        private void btnGolesteImport_Click(object sender, RoutedEventArgs e)
        {
            txtImportStoc.Clear();
            _importItems.Clear();
            listImportStoc.ItemsSource = null;
        }
        public StocuriPage()
        {
            InitializeComponent();
            IncarcaDate();
            listStocuri.SelectionChanged += (s, e) =>
            {
                if (listStocuri.SelectedItem is StocDisplay sd)
                {
                    _stocSelectat = sd;
                    txtIngredientSelectat.Text = $"Ingredient: {sd.NumeIngredient} ({sd.CantitateDisponibila} {sd.UnitateMasura})";
                    txtIngredientSelectat.Foreground = new SolidColorBrush(Colors.White);
                }
            };
            listStocManual.SelectionChanged += (s, e) =>
            {
                if (listStocManual.SelectedItem is StocManualDisplay sm)
                {
                    _stocManualSelectat = sm;
                    txtProdusManualSelectat.Text = $"Produs: {sm.NumeProdus} ({sm.Cantitate} {sm.Unitate})";
                    txtProdusManualSelectat.Foreground = new SolidColorBrush(Colors.White);
                }
            };
        }

        private void IncarcaDate()
        {
            IncarcaStocuri();
            IncarcaStocManual();
            IncarcaStocCritic();
        }

        private void IncarcaStocuri()
        {
            var lista = new List<StocDisplay>();
            using var conn = DatabaseHelper.GetConnection();
            conn.Open();
            string query = @"SELECT S.id, S.id_ingredient, I.nume,
                            S.cantitate_disponibila, S.cantitate_minima, I.unitate_masura
                            FROM Stocuri S
                            INNER JOIN Ingrediente I ON S.id_ingredient = I.id
                            ORDER BY I.nume";
            using var cmd = new SqlCommand(query, conn);
            using var reader = cmd.ExecuteReader();
            while (reader.Read())
            {
                lista.Add(new StocDisplay
                {
                    Id = reader.GetInt32(0),
                    IdIngredient = reader.GetInt32(1),
                    NumeIngredient = reader.GetString(2),
                    CantitateDisponibila = reader.GetDecimal(3),
                    CantitateMinima = reader.GetDecimal(4),
                    UnitateMasura = reader.GetString(5)
                });
            }
            listStocuri.ItemsSource = lista;
        }

        private void IncarcaStocManual()
        {
            var lista = new List<StocManualDisplay>();
            using var conn = DatabaseHelper.GetConnection();
            conn.Open();
            string query = "SELECT id, nume_produs, unitate, cantitate, cantitate_minima FROM Stoc_Manual ORDER BY nume_produs";
            using var cmd = new SqlCommand(query, conn);
            using var reader = cmd.ExecuteReader();
            while (reader.Read())
            {
                lista.Add(new StocManualDisplay
                {
                    Id = reader.GetInt32(0),
                    NumeProdus = reader.GetString(1),
                    Unitate = reader.GetString(2),
                    Cantitate = reader.GetDecimal(3),
                    CantitateMinima = reader.GetDecimal(4)
                });
            }
            listStocManual.ItemsSource = lista;
        }

        private void IncarcaStocCritic()
        {
            var lista = new List<StocDisplay>();
            using var conn = DatabaseHelper.GetConnection();
            conn.Open();
            string query = @"SELECT S.id, S.id_ingredient, I.nume,
                            S.cantitate_disponibila, S.cantitate_minima, I.unitate_masura
                            FROM Stocuri S
                            INNER JOIN Ingrediente I ON S.id_ingredient = I.id
                            WHERE S.cantitate_disponibila <= S.cantitate_minima
                            ORDER BY S.cantitate_disponibila ASC";
            using var cmd = new SqlCommand(query, conn);
            using var reader = cmd.ExecuteReader();
            while (reader.Read())
            {
                lista.Add(new StocDisplay
                {
                    Id = reader.GetInt32(0),
                    IdIngredient = reader.GetInt32(1),
                    NumeIngredient = reader.GetString(2),
                    CantitateDisponibila = reader.GetDecimal(3),
                    CantitateMinima = reader.GetDecimal(4),
                    UnitateMasura = reader.GetString(5)
                });
            }
            listStocCritic.ItemsSource = lista;
        }

        private void btnAdaugaStoc_Click(object sender, RoutedEventArgs e)
        {
            if (_stocSelectat == null)
            {
                MessageBox.Show("Selectați un ingredient!", "Atenție",
                    MessageBoxButton.OK, MessageBoxImage.Warning);
                return;
            }

            if (!decimal.TryParse(txtCantitateNoua.Text.Replace(",", "."),
                System.Globalization.NumberStyles.Any,
                System.Globalization.CultureInfo.InvariantCulture,
                out decimal cantitate) || cantitate <= 0)
            {
                MessageBox.Show("Introduceți o cantitate validă!", "Atenție",
                    MessageBoxButton.OK, MessageBoxImage.Warning);
                return;
            }

            using var conn = DatabaseHelper.GetConnection();
            conn.Open();
            string query = @"UPDATE Stocuri 
                            SET cantitate_disponibila = cantitate_disponibila + @c
                            WHERE id_ingredient = @i";
            using var cmd = new SqlCommand(query, conn);
            cmd.Parameters.AddWithValue("@c", cantitate);
            cmd.Parameters.AddWithValue("@i", _stocSelectat.IdIngredient);
            cmd.ExecuteNonQuery();

            MessageBox.Show($"✅ Adăugat {cantitate} {_stocSelectat.UnitateMasura} la {_stocSelectat.NumeIngredient}!",
                "Succes", MessageBoxButton.OK, MessageBoxImage.Information);

            txtCantitateNoua.Clear();
            _stocSelectat = null;
            txtIngredientSelectat.Text = "Selectați un ingredient din listă";
            IncarcaDate();
        }

        private void btnActualizeazaManual_Click(object sender, RoutedEventArgs e)
        {
            if (_stocManualSelectat == null)
            {
                MessageBox.Show("Selectați un produs!", "Atenție",
                    MessageBoxButton.OK, MessageBoxImage.Warning);
                return;
            }

            if (!decimal.TryParse(txtCantitateManual.Text.Replace(",", "."),
                System.Globalization.NumberStyles.Any,
                System.Globalization.CultureInfo.InvariantCulture,
                out decimal cantitate) || cantitate < 0)
            {
                MessageBox.Show("Introduceți o cantitate validă!", "Atenție",
                    MessageBoxButton.OK, MessageBoxImage.Warning);
                return;
            }

            using var conn = DatabaseHelper.GetConnection();
            conn.Open();
            string query = @"UPDATE Stoc_Manual 
                            SET cantitate = @c, data_actualizare = GETDATE()
                            WHERE id = @i";
            using var cmd = new SqlCommand(query, conn);
            cmd.Parameters.AddWithValue("@c", cantitate);
            cmd.Parameters.AddWithValue("@i", _stocManualSelectat.Id);
            cmd.ExecuteNonQuery();

            MessageBox.Show($"✅ Stoc actualizat: {_stocManualSelectat.NumeProdus} = {cantitate} {_stocManualSelectat.Unitate}",
                "Succes", MessageBoxButton.OK, MessageBoxImage.Information);

            txtCantitateManual.Clear();
            _stocManualSelectat = null;
            txtProdusManualSelectat.Text = "Selectați un produs din listă";
            IncarcaDate();
        }

        private void btnRefresh_Click(object sender, RoutedEventArgs e)
        {
            IncarcaDate();
            MessageBox.Show("Lista actualizată!", "Info",
                MessageBoxButton.OK, MessageBoxImage.Information);
        }

    }
}