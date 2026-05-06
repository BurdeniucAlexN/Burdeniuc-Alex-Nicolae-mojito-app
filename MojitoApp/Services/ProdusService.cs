using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

using Microsoft.Data.SqlClient;
using MojitoApp.Helpers;
using MojitoApp.Models;

namespace MojitoApp.Services
{
    public class ProdusService
    {
        public List<Produs> GetByCategorie(string tip)
        {
            var lista = new List<Produs>();
            using var conn = DatabaseHelper.GetConnection();
            conn.Open();
            string query = @"SELECT P.id, P.nume, P.id_categorie, P.pret, 
                            P.gramaj, P.tip_scadere 
                            FROM Produse P
                            INNER JOIN Categorii C ON P.id_categorie = C.id
                            WHERE C.tip = @tip";
            using var cmd = new SqlCommand(query, conn);
            cmd.Parameters.AddWithValue("@tip", tip);
            using var reader = cmd.ExecuteReader();
            while (reader.Read())
            {
                lista.Add(new Produs
                {
                    Id = reader.GetInt32(0),
                    Nume = reader.GetString(1),
                    IdCategorie = reader.GetInt32(2),
                    Pret = reader.GetDecimal(3),
                    Gramaj = reader.IsDBNull(4) ? "" : reader.GetString(4),
                    TipScadere = reader.GetString(5)
                });
            }
            return lista;
        }
    }
}