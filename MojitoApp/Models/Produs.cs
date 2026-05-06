using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace MojitoApp.Models
{
    public class Produs
    {
        public int Id { get; set; }
        public string Nume { get; set; } = "";
        public int IdCategorie { get; set; }
        public decimal Pret { get; set; }
        public string Gramaj { get; set; } = "";
        public string TipScadere { get; set; } = "";
    }
}