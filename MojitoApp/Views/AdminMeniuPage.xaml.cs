using System.Windows;
using System.Windows.Controls;
using Microsoft.Data.SqlClient;
using MojitoApp.Helpers;

namespace MojitoApp.Views
{
    public class ProdusAdmin
    {
        public int Id { get; set; }
        public string Nume { get; set; } = "";
        public string Gramaj { get; set; } = "";
        public decimal Pret { get; set; }
        public int IdCategorie { get; set; }
        public string TipScadere { get; set; } = "";
    }

    public class RetetaItem
    {
        public int IdIngredient { get; set; }
        public string NumeIngredient { get; set; } = "";
        public decimal Cantitate { get; set; }
        public string Unitate { get; set; } = "";
    }

    public class IngredientItem
    {
        public int Id { get; set; }
        public string Nume { get; set; } = "";
        public override string ToString() => Nume;
    }

    public partial class AdminMeniuPage : Page
    {
        private int _idProdusSelectat = -1;
        private int _idProdusReteta = -1;
        private List<RetetaItem> _retetaCurenta = new();

        public AdminMeniuPage()
        {
            InitializeComponent();
            IncarcaCategории();
            IncarcaToateProdusele();
            IncarcaIngrediente();
        }

        private void IncarcaCategории()
        {
            using var conn = DatabaseHelper.GetConnection();
            conn.Open();
            string query = "SELECT id, nume FROM Categorii ORDER BY id";
            using var cmd = new SqlCommand(query, conn);
            using var reader = cmd.ExecuteReader();
            var categorii = new List<(int id, string nume)>();
            categorii.Add((0, "— Toate categoriile —"));
            while (reader.Read())
                categorii.Add((reader.GetInt32(0), reader.GetString(1)));
            cmbCategorie.ItemsSource = categorii.Select(c => c.nume).ToList();
            cmbCategorie.SelectedIndex = 0;
        }

        private void IncarcaToateProdusele()
        {
            var lista = GetProduse(0);
            listProduseMeniu.ItemsSource = lista;
            listProduseRetete.ItemsSource = lista;
        }

        private List<ProdusAdmin> GetProduse(int idCategorie)
        {
            var lista = new List<ProdusAdmin>();
            using var conn = DatabaseHelper.GetConnection();
            conn.Open();
            string query = idCategorie == 0
                ? "SELECT id, nume, gramaj, pret, id_categorie, tip_scadere FROM Produse ORDER BY id_categorie, nume"
                : "SELECT id, nume, gramaj, pret, id_categorie, tip_scadere FROM Produse WHERE id_categorie=@c ORDER BY nume";
            using var cmd = new SqlCommand(query, conn);
            if (idCategorie > 0) cmd.Parameters.AddWithValue("@c", idCategorie);
            using var reader = cmd.ExecuteReader();
            while (reader.Read())
            {
                lista.Add(new ProdusAdmin
                {
                    Id = reader.GetInt32(0),
                    Nume = reader.GetString(1),
                    Gramaj = reader.IsDBNull(2) ? "" : reader.GetString(2),
                    Pret = reader.GetDecimal(3),
                    IdCategorie = reader.GetInt32(4),
                    TipScadere = reader.GetString(5)
                });
            }
            return lista;
        }

        private void IncarcaIngrediente()
        {
            var lista = new List<IngredientItem>();
            using var conn = DatabaseHelper.GetConnection();
            conn.Open();
            string query = "SELECT id, nume FROM Ingrediente ORDER BY nume";
            using var cmd = new SqlCommand(query, conn);
            using var reader = cmd.ExecuteReader();
            while (reader.Read())
                lista.Add(new IngredientItem
                {
                    Id = reader.GetInt32(0),
                    Nume = reader.GetString(1)
                });
            cmbIngredient.ItemsSource = lista;
        }

        private void cmbCategorie_SelectionChanged(object sender, SelectionChangedEventArgs e)
        {
            int index = cmbCategorie.SelectedIndex;
            listProduseMeniu.ItemsSource = GetProduse(index);
        }

        private void listProduseMeniu_SelectionChanged(object sender, SelectionChangedEventArgs e)
        {
            if (listProduseMeniu.SelectedItem is ProdusAdmin p)
            {
                _idProdusSelectat = p.Id;
                txtTitluFormular.Text = $"✏ Editare: {p.Nume}";
                txtNumeProdus.Text = p.Nume;
                txtPretProdus.Text = p.Pret.ToString("F2");
                txtGramajProdus.Text = p.Gramaj;
                btnSalvProdus.Content = "💾 ACTUALIZEAZĂ";
            }
        }

        private void btnAnuleaza_Click(object sender, RoutedEventArgs e)
        {
            _idProdusSelectat = -1;
            txtTitluFormular.Text = "➕ Produs Nou";
            txtNumeProdus.Clear();
            txtPretProdus.Clear();
            txtGramajProdus.Clear();
            btnSalvProdus.Content = "💾 SALVEAZĂ";
            listProduseMeniu.SelectedItem = null;
        }

        private void btnSalvProdus_Click(object sender, RoutedEventArgs e)
        {
            if (string.IsNullOrWhiteSpace(txtNumeProdus.Text) ||
                !decimal.TryParse(txtPretProdus.Text.Replace(",", "."),
                System.Globalization.NumberStyles.Any,
                System.Globalization.CultureInfo.InvariantCulture,
                out decimal pret))
            {
                MessageBox.Show("Completați Nume și Preț valid!", "Atenție",
                    MessageBoxButton.OK, MessageBoxImage.Warning);
                return;
            }

            using var conn = DatabaseHelper.GetConnection();
            conn.Open();

            if (_idProdusSelectat > 0)
            {
                // Actualizare
                string query = @"UPDATE Produse SET nume=@n, pret=@p, gramaj=@g 
                                WHERE id=@id";
                using var cmd = new SqlCommand(query, conn);
                cmd.Parameters.AddWithValue("@n", txtNumeProdus.Text.Trim());
                cmd.Parameters.AddWithValue("@p", pret);
                cmd.Parameters.AddWithValue("@g", txtGramajProdus.Text.Trim());
                cmd.Parameters.AddWithValue("@id", _idProdusSelectat);
                cmd.ExecuteNonQuery();
                MessageBox.Show("✅ Produs actualizat!", "Succes",
                    MessageBoxButton.OK, MessageBoxImage.Information);
            }
            else
            {
                MessageBox.Show("Selectați un produs pentru editare sau folosiți formularul pentru adăugare nouă!",
                    "Info", MessageBoxButton.OK, MessageBoxImage.Information);
                return;
            }

            IncarcaToateProdusele();
            btnAnuleaza_Click(sender, e);
        }

        private void btnStergeProdus_Click(object sender, RoutedEventArgs e)
        {
            if (listProduseMeniu.SelectedItem is not ProdusAdmin p)
            {
                MessageBox.Show("Selectați un produs!", "Atenție",
                    MessageBoxButton.OK, MessageBoxImage.Warning);
                return;
            }

            var conf = MessageBox.Show($"Ștergeți produsul '{p.Nume}'?",
                "Confirmare", MessageBoxButton.YesNo, MessageBoxImage.Question);

            if (conf == MessageBoxResult.Yes)
            {
                using var conn = DatabaseHelper.GetConnection();
                conn.Open();
                // Stergem mai intai reteta
                new SqlCommand($"DELETE FROM Produs_Ingrediente WHERE id_produs={p.Id}", conn).ExecuteNonQuery();
                new SqlCommand($"DELETE FROM Produse WHERE id={p.Id}", conn).ExecuteNonQuery();

                MessageBox.Show("✅ Produs șters!", "Succes",
                    MessageBoxButton.OK, MessageBoxImage.Information);
                IncarcaToateProdusele();
                btnAnuleaza_Click(sender, e);
            }
        }

        // ===== RETETE =====
        private void listProduseRetete_SelectionChanged(object sender, SelectionChangedEventArgs e)
        {
            if (listProduseRetete.SelectedItem is ProdusAdmin p)
            {
                _idProdusReteta = p.Id;
                txtNumeProdusSel.Text = $"📋 {p.Nume}";
                IncarcaReteta(p.Id);
            }
        }

        private void IncarcaReteta(int idProdus)
        {
            _retetaCurenta = new List<RetetaItem>();
            using var conn = DatabaseHelper.GetConnection();
            conn.Open();
            string query = @"SELECT PI.id_ingredient, I.nume, PI.cantitate, I.unitate_masura
                            FROM Produs_Ingrediente PI
                            INNER JOIN Ingrediente I ON PI.id_ingredient = I.id
                            WHERE PI.id_produs = @id
                            ORDER BY I.nume";
            using var cmd = new SqlCommand(query, conn);
            cmd.Parameters.AddWithValue("@id", idProdus);
            using var reader = cmd.ExecuteReader();
            while (reader.Read())
            {
                _retetaCurenta.Add(new RetetaItem
                {
                    IdIngredient = reader.GetInt32(0),
                    NumeIngredient = reader.GetString(1),
                    Cantitate = reader.GetDecimal(2),
                    Unitate = reader.GetString(3)
                });
            }
            listReteta.ItemsSource = null;
            listReteta.ItemsSource = _retetaCurenta;
        }

        private void btnAdaugaIngredient_Click(object sender, RoutedEventArgs e)
        {
            if (_idProdusReteta < 0)
            {
                MessageBox.Show("Selectați un produs!", "Atenție",
                    MessageBoxButton.OK, MessageBoxImage.Warning);
                return;
            }

            if (cmbIngredient.SelectedItem is not IngredientItem ing)
            {
                MessageBox.Show("Selectați un ingredient!", "Atenție",
                    MessageBoxButton.OK, MessageBoxImage.Warning);
                return;
            }

            if (!decimal.TryParse(txtCantitateIng.Text.Replace(",", "."),
                System.Globalization.NumberStyles.Any,
                System.Globalization.CultureInfo.InvariantCulture,
                out decimal cant) || cant <= 0)
            {
                MessageBox.Show("Introduceți cantitate validă!", "Atenție",
                    MessageBoxButton.OK, MessageBoxImage.Warning);
                return;
            }

            // Verificam daca exista deja
            var existent = _retetaCurenta.FirstOrDefault(r => r.IdIngredient == ing.Id);
            if (existent != null)
                existent.Cantitate = cant;
            else
                _retetaCurenta.Add(new RetetaItem
                {
                    IdIngredient = ing.Id,
                    NumeIngredient = ing.Nume,
                    Cantitate = cant,
                    Unitate = ""
                });

            listReteta.ItemsSource = null;
            listReteta.ItemsSource = _retetaCurenta;
            txtCantitateIng.Clear();
        }

        private void btnSalveazaReteta_Click(object sender, RoutedEventArgs e)
        {
            if (_idProdusReteta < 0)
            {
                MessageBox.Show("Selectați un produs!", "Atenție",
                    MessageBoxButton.OK, MessageBoxImage.Warning);
                return;
            }

            var conf = MessageBox.Show(
                $"Salvați rețeta cu {_retetaCurenta.Count} ingrediente?",
                "Confirmare", MessageBoxButton.YesNo, MessageBoxImage.Question);

            if (conf == MessageBoxResult.Yes)
            {
                using var conn = DatabaseHelper.GetConnection();
                conn.Open();

                // Stergem reteta veche
                new SqlCommand(
                    $"DELETE FROM Produs_Ingrediente WHERE id_produs={_idProdusReteta}",
                    conn).ExecuteNonQuery();

                // Inserăm reteta noua
                foreach (var item in _retetaCurenta)
                {
                    string query = @"INSERT INTO Produs_Ingrediente 
                                    (id_produs, id_ingredient, cantitate)
                                    VALUES (@p, @i, @c)";
                    using var cmd = new SqlCommand(query, conn);
                    cmd.Parameters.AddWithValue("@p", _idProdusReteta);
                    cmd.Parameters.AddWithValue("@i", item.IdIngredient);
                    cmd.Parameters.AddWithValue("@c", item.Cantitate);
                    cmd.ExecuteNonQuery();
                }

                MessageBox.Show("✅ Rețetă salvată cu succes!", "Succes",
                    MessageBoxButton.OK, MessageBoxImage.Information);

                IncarcaReteta(_idProdusReteta);
            }
        }
    }
}