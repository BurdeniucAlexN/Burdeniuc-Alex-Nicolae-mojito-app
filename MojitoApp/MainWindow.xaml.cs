using System.Windows;
using MojitoApp.Helpers;

namespace MojitoApp
{
    public partial class MainWindow : Window
    {
        public MainWindow()
        {
            InitializeComponent();
            if (DatabaseHelper.TestConnection())
                MessageBox.Show("Conexiune la MojitoDB reușită!", "Success",
                    MessageBoxButton.OK, MessageBoxImage.Information);
            else
                MessageBox.Show("Eroare la conectare!", "Error",
                    MessageBoxButton.OK, MessageBoxImage.Error);
        }
    }
}