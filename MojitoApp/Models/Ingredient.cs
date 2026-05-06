using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace MojitoApp.Models
{
    public class Ingredient
    {
        public int Id { get; set; }
        public string Nume { get; set; } = "";
        public string UnitateMasura { get; set; } = "";
    }
}
