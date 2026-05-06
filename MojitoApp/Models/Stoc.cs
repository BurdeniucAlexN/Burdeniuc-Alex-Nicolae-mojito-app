using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace MojitoApp.Models
{
    public class Stoc
    {
        public int Id { get; set; }
        public int IdIngredient { get; set; }
        public string NumeIngredient { get; set; } = "";
        public decimal CantitateDisponibila { get; set; }
        public decimal CantitateMinima { get; set; }
        public string UnitateMasura { get; set; } = "";
    }
}
