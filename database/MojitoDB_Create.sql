-- ============================================================
--  MojitoDB — Baza de date pentru aplicatia Mojito
--  Opera Magna SRL | Proiect practica PAPP-231
--  Autor: Burdeniuc Alex-Nicolae
--  Data: Mai 2026
-- ============================================================

USE master;
GO

IF EXISTS (SELECT name FROM sys.databases WHERE name = 'MojitoDB')
    DROP DATABASE MojitoDB;
GO

CREATE DATABASE MojitoDB;
GO

USE MojitoDB;
GO

-- ============================================================
--  1. CATEGORII
--  tip: 'european' | 'japonez' | 'bar' | 'bauturi' | 'manual'
-- ============================================================
CREATE TABLE Categorii (
    id    INT IDENTITY(1,1) PRIMARY KEY,
    nume  NVARCHAR(100) NOT NULL,
    tip   NVARCHAR(50)  NOT NULL
);
GO

-- ============================================================
--  2. INGREDIENTE
--  unitate_masura: 'g' | 'ml' | 'buc'
-- ============================================================
CREATE TABLE Ingrediente (
    id              INT IDENTITY(1,1) PRIMARY KEY,
    nume            NVARCHAR(150) NOT NULL,
    unitate_masura  NVARCHAR(10)  NOT NULL CHECK (unitate_masura IN ('g','ml','buc'))
);
GO

-- ============================================================
--  3. STOCURI — cantitati curente pentru fiecare ingredient
-- ============================================================
CREATE TABLE Stocuri (
    id                    INT IDENTITY(1,1) PRIMARY KEY,
    id_ingredient         INT NOT NULL REFERENCES Ingrediente(id),
    cantitate_disponibila DECIMAL(10,2) NOT NULL DEFAULT 0,
    cantitate_minima      DECIMAL(10,2) NOT NULL DEFAULT 0
);
GO

-- ============================================================
--  4. PRODUSE
--  tip_scadere: 'ingrediente' | 'portie' | 'bucata' | 'premix' | 'manual'
-- ============================================================
CREATE TABLE Produse (
    id           INT IDENTITY(1,1) PRIMARY KEY,
    nume         NVARCHAR(200) NOT NULL,
    id_categorie INT           NOT NULL REFERENCES Categorii(id),
    pret         DECIMAL(10,2) NOT NULL,
    gramaj       NVARCHAR(50)  NULL,
    tip_scadere  NVARCHAR(20)  NOT NULL
        CHECK (tip_scadere IN ('ingrediente','portie','bucata','premix','manual'))
);
GO

-- ============================================================
--  5. PRODUS_INGREDIENTE — reteta fiecarui produs
-- ============================================================
CREATE TABLE Produs_Ingrediente (
    id_produs     INT           NOT NULL REFERENCES Produse(id),
    id_ingredient INT           NOT NULL REFERENCES Ingrediente(id),
    cantitate     DECIMAL(10,2) NOT NULL,
    PRIMARY KEY (id_produs, id_ingredient)
);
GO

-- ============================================================
--  6. ANGAJATI
--  rol: 'admin' | 'chelner'
-- ============================================================
CREATE TABLE Angajati (
    id          INT IDENTITY(1,1) PRIMARY KEY,
    nume        NVARCHAR(100) NOT NULL,
    prenume     NVARCHAR(100) NOT NULL,
    rol         NVARCHAR(20)  NOT NULL CHECK (rol IN ('admin','chelner')),
    username    NVARCHAR(100) NOT NULL UNIQUE,
    parola_hash NVARCHAR(256) NOT NULL
);
GO

-- ============================================================
--  7. VANZARI
-- ============================================================
CREATE TABLE Vanzari (
    id          INT IDENTITY(1,1) PRIMARY KEY,
    id_angajat  INT           NOT NULL REFERENCES Angajati(id),
    data_ora    DATETIME      NOT NULL DEFAULT GETDATE(),
    total       DECIMAL(10,2) NOT NULL DEFAULT 0
);
GO

-- ============================================================
--  8. DETALII_VANZARI
-- ============================================================
CREATE TABLE Detalii_Vanzari (
    id          INT IDENTITY(1,1) PRIMARY KEY,
    id_vanzare  INT           NOT NULL REFERENCES Vanzari(id),
    id_produs   INT           NOT NULL REFERENCES Produse(id),
    cantitate   INT           NOT NULL DEFAULT 1,
    pret_unitar DECIMAL(10,2) NOT NULL
);
GO

-- ============================================================
--  9. STOC_MANUAL — produse care nu se tasteaza
--     (hartie, servetele, manusi, betisoare, zahar etc.)
-- ============================================================
CREATE TABLE Stoc_Manual (
    id               INT IDENTITY(1,1) PRIMARY KEY,
    nume_produs      NVARCHAR(200) NOT NULL,
    unitate          NVARCHAR(50)  NOT NULL,
    cantitate        DECIMAL(10,2) NOT NULL DEFAULT 0,
    cantitate_minima DECIMAL(10,2) NOT NULL DEFAULT 0,
    data_actualizare DATETIME      NOT NULL DEFAULT GETDATE()
);
GO

-- ============================================================
--  10. LOG_ACTIVITATE — cine a facut ce si cand
-- ============================================================
CREATE TABLE Log_Activitate (
    id          INT IDENTITY(1,1) PRIMARY KEY,
    id_angajat  INT           NOT NULL REFERENCES Angajati(id),
    actiune     NVARCHAR(500) NOT NULL,
    data_ora    DATETIME      NOT NULL DEFAULT GETDATE()
);
GO

-- ============================================================
--  STORED PROCEDURE: scadere automata stoc dupa vanzare
-- ============================================================
CREATE OR ALTER PROCEDURE sp_ScadeStocDupaVanzare
    @id_vanzare INT
AS
BEGIN
    SET NOCOUNT ON;

    -- Pentru produse cu reteta (ingrediente / premix)
    UPDATE S
    SET S.cantitate_disponibila = S.cantitate_disponibila
        - (PI.cantitate * DV.cantitate)
    FROM Stocuri S
    INNER JOIN Produs_Ingrediente PI ON S.id_ingredient = PI.id_ingredient
    INNER JOIN Detalii_Vanzari DV   ON PI.id_produs     = DV.id_produs
    INNER JOIN Produse P            ON DV.id_produs      = P.id
    WHERE DV.id_vanzare = @id_vanzare
      AND P.tip_scadere IN ('ingrediente','premix');

    -- Pentru bauturi tari: 40 ml per portie din ingredientul principal
    UPDATE S
    SET S.cantitate_disponibila = S.cantitate_disponibila - (40 * DV.cantitate)
    FROM Stocuri S
    INNER JOIN Produs_Ingrediente PI ON S.id_ingredient = PI.id_ingredient
    INNER JOIN Detalii_Vanzari DV   ON PI.id_produs     = DV.id_produs
    INNER JOIN Produse P            ON DV.id_produs      = P.id
    WHERE DV.id_vanzare = @id_vanzare
      AND P.tip_scadere = 'portie';

    -- Pentru produse unitare (bucati)
    UPDATE S
    SET S.cantitate_disponibila = S.cantitate_disponibila - DV.cantitate
    FROM Stocuri S
    INNER JOIN Produs_Ingrediente PI ON S.id_ingredient = PI.id_ingredient
    INNER JOIN Detalii_Vanzari DV   ON PI.id_produs     = DV.id_produs
    INNER JOIN Produse P            ON DV.id_produs      = P.id
    WHERE DV.id_vanzare = @id_vanzare
      AND P.tip_scadere = 'bucata';
END;
GO

-- ============================================================
--  STORED PROCEDURE: produse cu stoc critic (sub minim)
-- ============================================================
CREATE OR ALTER PROCEDURE sp_StocCritic
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        I.nume            AS Ingredient,
        S.cantitate_disponibila AS Disponibil,
        S.cantitate_minima      AS Minim,
        I.unitate_masura        AS Unitate
    FROM Stocuri S
    INNER JOIN Ingrediente I ON S.id_ingredient = I.id
    WHERE S.cantitate_disponibila <= S.cantitate_minima
    ORDER BY S.cantitate_disponibila ASC;
END;
GO

-- ============================================================
--  SEED: date initiale — categorii
-- ============================================================
INSERT INTO Categorii (nume, tip) VALUES
    ('Bucatarie Europeana',  'european'),
    ('Bucatarie Japoneza',   'japonez'),
    ('Cocktailuri & Bar',    'bar'),
    ('Bauturi Unitare',      'bauturi'),
    ('Bauturi Spirtoase',    'bauturi'),
    ('Stoc Manual',          'manual');
GO

-- ============================================================
--  SEED: angajat admin implicit
--  parola: Admin1234 (SHA-256, de inlocuit in aplicatie)
-- ============================================================
INSERT INTO Angajati (nume, prenume, rol, username, parola_hash) VALUES
    ('Burdeniuc', 'Alex-Nicolae', 'admin', 'admin',
     '0f775e65d2e83ed532d4339d29a4bddf81d27f65c60e0dc8893068c04cfa0b65');
GO

-- ============================================================
--  SEED: stoc manual initial
-- ============================================================
INSERT INTO Stoc_Manual (nume_produs, unitate, cantitate, cantitate_minima) VALUES
    ('Hartie igienica',      'rola',  50,  10),
    ('Servetele de masa',    'buc',   500, 100),
    ('Manusi latex',         'buc',   200, 50),
    ('Betisoare pentru sushi','set',  300, 50),
    ('Zahar portionat',      'plic',  400, 100),
    ('Scobitori',            'buc',   1000,200),
    ('Pungi menaj',          'buc',   100, 20),
    ('Folie alimentara',     'rola',  5,   1),
    ('Detergent vase',       'l',     10,  2),
    ('Burete vase',          'buc',   20,  5);
GO

PRINT 'MojitoDB creat cu succes!';
GO


USE MojitoDB;

INSERT INTO Ingrediente (nume, unitate_masura) VALUES
('Piept de pui',     'g'),
('Cartofi',          'g'),
('Ulei floarea soarelui', 'ml'),
('Orez pentru sushi','g'),
('Somon proaspat',   'g'),
('Vodca',            'ml'),
('Premix Mojito',    'ml'),
('Dorna 0.3L',       'buc'),
('Cola 0.25L',       'buc'),
('Lamaie',           'g');
GO

INSERT INTO Stocuri (id_ingredient, cantitate_disponibila, cantitate_minima) VALUES
(1,  5000, 500),   -- Piept de pui: 5kg, minim 500g
(2,  8000, 1000),  -- Cartofi: 8kg, minim 1kg
(3,  3000, 500),   -- Ulei: 3L, minim 500ml
(4,  5000, 500),   -- Orez sushi: 5kg, minim 500g
(5,  3000, 300),   -- Somon: 3kg, minim 300g
(6,  5000, 400),   -- Vodca: 5L, minim 400ml
(7,  4000, 400),   -- Premix Mojito: 4L, minim 400ml
(8,  48,   6),     -- Dorna: 48 buc, minim 6
(9,  48,   6),     -- Cola: 48 buc, minim 6
(10, 2000, 200);   -- Lamaie: 2kg, minim 200g
GO

SELECT 
    I.nume            AS Ingredient,
    S.cantitate_disponibila AS Disponibil,
    S.cantitate_minima      AS Minim,
    I.unitate_masura        AS Unitate
FROM Stocuri S
INNER JOIN Ingrediente I ON S.id_ingredient = I.id
ORDER BY I.nume;
GO

USE MojitoDB;

-- Inserare produs test (Vodca 40ml portie)
INSERT INTO Produse (nume, id_categorie, pret, gramaj, tip_scadere) VALUES
('Vodca Absolut', 5, 45.00, '40ml', 'portie');

-- Inserare vanzare test
INSERT INTO Vanzari (id_angajat, total) VALUES (1, 45.00);

-- Inserare detaliu vanzare (1 portie vodca)
INSERT INTO Detalii_Vanzari (id_vanzare, id_produs, cantitate, pret_unitar)
VALUES (1, 1, 1, 45.00);
GO

EXEC sp_ScadeStocDupaVanzare @id_vanzare = 1;
GO

SELECT 
    I.nume        AS Ingredient,
    S.cantitate_disponibila AS Dupa_Vanzare,
    I.unitate_masura AS Unitate
FROM Stocuri S
INNER JOIN Ingrediente I ON S.id_ingredient = I.id
WHERE I.nume = 'Vodca';
GO

EXEC sp_StocCritic;
GO

USE MojitoDB;

-- Legam produsul Vodca Absolut (id=1) de ingredientul Vodca (id=6)
INSERT INTO Produs_Ingrediente (id_produs, id_ingredient, cantitate)
VALUES (1, 6, 40);  -- 40ml per portie
GO

-- Rulam din nou procedura
EXEC sp_ScadeStocDupaVanzare @id_vanzare = 1;
GO

-- Verificam stocul
SELECT 
    I.nume AS Ingredient,
    S.cantitate_disponibila AS Dupa_Vanzare,
    I.unitate_masura AS Unitate
FROM Stocuri S
INNER JOIN Ingrediente I ON S.id_ingredient = I.id
WHERE I.nume = 'Vodca';
GO

-- Simulam un stoc critic pentru test
UPDATE Stocuri SET cantitate_disponibila = 3 WHERE id_ingredient = 8; -- Dorna sub minim
UPDATE Stocuri SET cantitate_disponibila = 2 WHERE id_ingredient = 9; -- Cola sub minim
GO

EXEC sp_StocCritic;
GO

USE MojitoDB;

UPDATE Angajati 
SET parola_hash = '0f775e65d2e83ed532d4339d29a4bddf81d27f65c60e0dc8893068c04cfa0b65'
WHERE username = 'admin';

SELECT username, parola_hash FROM Angajati;
GO

USE MojitoDB;

UPDATE Angajati 
SET parola_hash = '60fe74406e7f353ed979f350f2fbb6a2e8690a5fa7d1b0c32983d1d8b3f95f67'
WHERE username = 'admin';
GO
USE MojitoDB;

INSERT INTO Produse (nume, id_categorie, pret, gramaj, tip_scadere) VALUES
('Supă de pui',         1, 45.00, '300ml', 'ingrediente'),
('Ciorbă de burtă',     1, 55.00, '300ml', 'ingrediente'),
('Cotlet de porc',      1, 89.00, '200g',  'ingrediente'),
('Piept de pui la grătar', 1, 79.00, '200g', 'ingrediente'),
('Cartofi prăjiți',     1, 35.00, '200g',  'ingrediente'),
('Salată de casă',      1, 40.00, '200g',  'ingrediente'),
('Paste Carbonara',     1, 75.00, '300g',  'ingrediente'),
('Pizza Margherita',    1, 85.00, '350g',  'ingrediente');
GO

USE MojitoDB;

INSERT INTO Produse (nume, id_categorie, pret, gramaj, tip_scadere) VALUES
('Philadelphia Roll',     2, 95.00,  '8 buc', 'ingrediente'),
('California Roll',       2, 85.00,  '8 buc', 'ingrediente'),
('Dragon Roll',           2, 110.00, '8 buc', 'ingrediente'),
('Spicy Tuna Roll',       2, 100.00, '8 buc', 'ingrediente'),
('Rainbow Roll',          2, 120.00, '8 buc', 'ingrediente'),
('Salmon Nigiri',         2, 65.00,  '2 buc', 'ingrediente'),
('Tuna Nigiri',           2, 70.00,  '2 buc', 'ingrediente'),
('Ebi Gunkan',            2, 60.00,  '2 buc', 'ingrediente'),
('Salmon Poke Bowl',      2, 115.00, '350g',  'ingrediente'),
('Tuna Poke Bowl',        2, 120.00, '350g',  'ingrediente');
GO

USE MojitoDB;

-- Stergere produse japoneze vechi
DELETE FROM Produs_Ingrediente WHERE id_produs IN (SELECT id FROM Produse WHERE id_categorie = 2);
DELETE FROM Produse WHERE id_categorie = 2;

-- Stergere ingrediente vechi de test
DELETE FROM Stocuri WHERE id_ingredient > 10;
DELETE FROM Ingrediente WHERE id > 10;

-- Ingrediente complete
INSERT INTO Ingrediente (nume, unitate_masura) VALUES
('Orez sushi',          'g'),   -- 11
('Nori',                'g'),   -- 12
('Crema de branza',     'g'),   -- 13
('Mango',               'g'),   -- 14
('Creveti',             'g'),   -- 15
('Castravete',          'g'),   -- 16
('Somon',               'g'),   -- 17
('Sos truffle aioli',   'g'),   -- 18
('Icre rosii',          'g'),   -- 19
('Ghimbir',             'g'),   -- 20
('Wasabi',              'g'),   -- 21
('Sos de soia',         'g'),   -- 22
('Icre masago',         'g'),   -- 23
('Avocado',             'g'),   -- 24
('Sos unagi',           'g'),   -- 25
('Sos picant',          'g'),   -- 26
('Tipar',               'g'),   -- 27
('Ton',                 'g'),   -- 28
('Seminte de susan',    'g'),   -- 29
('Omleta',              'g'),   -- 30
('Creveti tempura',     'g'),   -- 31
('Creveti pane',        'g'),   -- 32
('Creveti fierti',      'g'),   -- 33
('Somon flambat',       'g'),   -- 34
('Somon prajit',        'g'),   -- 35
('Foi de soia mamenori','g'),   -- 36
('Alge chuka',          'g'),   -- 37
('Salata iceberg',      'g'),   -- 38
('Ardei dulce',         'g'),   -- 39
('Salsa mango rosii',   'g'),   -- 40
('Busuioc',             'g'),   -- 41
('Panko',               'g'),   -- 42
('Icre tobiko',         'g'),   -- 43
('Tartar de tipar',     'g'),   -- 44
('Tartar de somon',     'g'),   -- 45
('Tartar de creveti',   'g'),   -- 46
('Takuan',              'g'),   -- 47
('Fulgi de ton',        'g'),   -- 48
('Praz prajit',         'g'),   -- 49
('Para kimchi',         'g'),   -- 50
('Edamame',             'g'),   -- 51
('Sos sweet chili',     'g'),   -- 52
('Rosii cherry',        'g'),   -- 53
('Porumb',              'g'),   -- 54
('Ridiche',             'g'),   -- 55
('Sos ponzu',           'g'),   -- 56
('Sos de nuci',         'g');   -- 57
GO
INSERT INTO Stocuri (id_ingredient, cantitate_disponibila, cantitate_minima)
SELECT id, 2000, 200 FROM Ingrediente WHERE id BETWEEN 11 AND 57;
GO

INSERT INTO Produse (nume, id_categorie, pret, gramaj, tip_scadere) VALUES
('Kitsune',                    2, 205.00, '280g', 'ingrediente'),  -- 1
('Alaska',                     2, 165.00, '280g', 'ingrediente'),  -- 2
('Yin & Yang',                 2, 175.00, '280g', 'ingrediente'),  -- 3
('Philadelphia Salmon',        2, 175.00, '280g', 'ingrediente'),  -- 4
('Philadelphia Shrimp',        2, 175.00, '280g', 'ingrediente'),  -- 5
('Philadelphia Eel',           2, 190.00, '280g', 'ingrediente'),  -- 6
('Philadelphia Tuna',          2, 190.00, '280g', 'ingrediente'),  -- 7
('Philly Roll',                2, 195.00, '280g', 'ingrediente'),  -- 8
('Canada',                     2, 190.00, '280g', 'ingrediente'),  -- 9
('Mojito Roll',                2, 255.00, '280g', 'ingrediente'),  -- 10
('Vegan',                      2, 105.00, '280g', 'ingrediente'),  -- 11
('Totoro',                     2, 200.00, '280g', 'ingrediente'),  -- 12
('Kyoto',                      2, 190.00, '280g', 'ingrediente'),  -- 13
('Yuki',                       2, 180.00, '280g', 'ingrediente'),  -- 14
('Ebi Tempura',                2, 175.00, '280g', 'ingrediente'),  -- 15
('Basilico Salmon Tempura',    2, 180.00, '280g', 'ingrediente'),  -- 16
('Salmon Tempura',             2, 175.00, '280g', 'ingrediente'),  -- 17
('Shiro Tempura',              2, 175.00, '280g', 'ingrediente'),  -- 18
('Umami Tempura',              2, 169.00, '280g', 'ingrediente'),  -- 19
('Nigiri Salmon',              2, 55.00,  '40g',  'ingrediente'),  -- 20
('Nigiri Seared Salmon',       2, 55.00,  '40g',  'ingrediente'),  -- 21
('Nigiri Tuna',                2, 50.00,  '40g',  'ingrediente'),  -- 22
('Nigiri Seared Tuna',         2, 50.00,  '40g',  'ingrediente'),  -- 23
('Nigiri Shrimp',              2, 50.00,  '40g',  'ingrediente'),  -- 24
('Nigiri Eel',                 2, 55.00,  '40g',  'ingrediente'),  -- 25
('Nigiri Seared Eel',          2, 55.00,  '40g',  'ingrediente'),  -- 26
('Gunkan Salmon',              2, 60.00,  '35g',  'ingrediente'),  -- 27
('Gunkan Red Caviar',          2, 65.00,  '35g',  'ingrediente'),  -- 28
('Gunkan Shrimp',              2, 55.00,  '35g',  'ingrediente'),  -- 29
('Gunkan Eel',                 2, 50.00,  '35g',  'ingrediente'),  -- 30
('Gunkan Tobiko',              2, 45.00,  '35g',  'ingrediente'),  -- 31
('Gunkan Chuka',               2, 45.00,  '35g',  'ingrediente'),  -- 32
('Crunch Poke',                2, 169.00, '350g', 'ingrediente'),  -- 33
('Tempura Shrimp Poke',        2, 169.00, '350g', 'ingrediente'),  -- 34
('Malibu Poke',                2, 169.00, '350g', 'ingrediente'),  -- 35
('Philly Poke',                2, 169.00, '350g', 'ingrediente'),  -- 36
('Fish Trio Poke',             2, 285.00, '350g', 'ingrediente');  -- 37
GO

SELECT id, nume FROM Produse WHERE id_categorie = 2 ORDER BY id;
GO
USE MojitoDB;

-- Kitsune (20): orez,nori,crema branza,mango,creveti,castravete,somon,sos truffle aioli,icre rosii,ghimbir,wasabi
INSERT INTO Produs_Ingrediente VALUES
(20,11,100),(20,12,5),(20,13,40),(20,14,20),(20,15,50),(20,16,20),(20,17,60),(20,18,15),(20,19,10),(20,20,10),(20,21,5);

-- Alaska (21): orez,nori,crema branza,mango,icre masago,avocado,creveti fierti,castravete,ghimbir,wasabi,sos soia
INSERT INTO Produs_Ingrediente VALUES
(21,11,100),(21,12,5),(21,13,40),(21,14,20),(21,23,10),(21,24,30),(21,33,50),(21,16,20),(21,20,10),(21,21,5),(21,22,15);

-- Yin & Yang (22): orez,nori,crema branza,mango,icre masago,castravete,creveti fierti,somon,sos unagi,sos picant,ghimbir,wasabi,sos soia
INSERT INTO Produs_Ingrediente VALUES
(22,11,100),(22,12,5),(22,13,40),(22,14,20),(22,23,10),(22,16,20),(22,33,50),(22,17,40),(22,25,15),(22,26,10),(22,20,10),(22,21,5),(22,22,15);

-- Philadelphia Salmon (23): orez,nori,crema branza,avocado,somon,ghimbir,wasabi,sos soia
INSERT INTO Produs_Ingrediente VALUES
(23,11,100),(23,12,5),(23,13,40),(23,24,30),(23,17,60),(23,20,10),(23,21,5),(23,22,15);

-- Philadelphia Shrimp (24): orez,nori,crema branza,avocado,creveti,sos unagi,sos picant,icre tobiko,ghimbir,wasabi,sos soia
INSERT INTO Produs_Ingrediente VALUES
(24,11,100),(24,12,5),(24,13,40),(24,24,30),(24,15,50),(24,25,15),(24,26,10),(24,43,10),(24,20,10),(24,21,5),(24,22,15);

-- Philadelphia Eel (25): orez,nori,crema branza,avocado,tipar,sos unagi,seminte susan,ghimbir,wasabi,sos soia
INSERT INTO Produs_Ingrediente VALUES
(25,11,100),(25,12,5),(25,13,40),(25,24,30),(25,27,60),(25,25,15),(25,29,5),(25,20,10),(25,21,5),(25,22,15);

-- Philadelphia Tuna (26): orez,nori,crema branza,avocado,ton,ghimbir,wasabi,sos soia
INSERT INTO Produs_Ingrediente VALUES
(26,11,100),(26,12,5),(26,13,40),(26,24,30),(26,28,60),(26,20,10),(26,21,5),(26,22,15);

-- Philly Roll (27): orez,nori,crema branza,tipar,castravete,somon,sos unagi,seminte susan,ghimbir,wasabi,sos soia
INSERT INTO Produs_Ingrediente VALUES
(27,11,100),(27,12,5),(27,13,40),(27,27,50),(27,16,20),(27,17,50),(27,25,15),(27,29,5),(27,20,10),(27,21,5),(27,22,15);

-- Canada (28): orez,nori,crema branza,avocado,omleta,tipar,sos unagi,seminte susan,ghimbir,wasabi,sos soia
INSERT INTO Produs_Ingrediente VALUES
(28,11,100),(28,12,5),(28,13,40),(28,24,30),(28,30,30),(28,27,50),(28,25,15),(28,29,5),(28,20,10),(28,21,5),(28,22,15);

-- Mojito Roll (29): orez,nori,crema branza,castravete,creveti tempura,somon,avocado,sos picant,sos unagi,icre rosii,ghimbir,wasabi,sos soia
INSERT INTO Produs_Ingrediente VALUES
(29,11,100),(29,12,5),(29,13,40),(29,16,20),(29,31,50),(29,17,50),(29,24,30),(29,26,10),(29,25,15),(29,19,10),(29,20,10),(29,21,5),(29,22,15);

-- Vegan (30): orez,nori,ardei dulce,castravete,avocado,salata iceberg,alge chuka,salsa mango rosii,seminte susan,sos unagi,ghimbir,wasabi,sos soia
INSERT INTO Produs_Ingrediente VALUES
(30,11,100),(30,12,5),(30,39,30),(30,16,20),(30,24,30),(30,38,20),(30,37,20),(30,40,20),(30,29,5),(30,25,15),(30,20,10),(30,21,5),(30,22,15);

-- Totoro (31): orez,nori,crema branza,creveti pane,avocado,somon flambat,sos picant,icre tobiko,sos unagi,seminte susan,ghimbir,wasabi,sos soia
INSERT INTO Produs_Ingrediente VALUES
(31,11,100),(31,12,5),(31,13,40),(31,32,50),(31,24,30),(31,34,50),(31,26,10),(31,43,10),(31,25,15),(31,29,5),(31,20,10),(31,21,5),(31,22,15);

-- Kyoto (32): orez,nori,crema branza,creveti pane,castravete,somon,sos picant,sos unagi,ghimbir,wasabi,sos soia
INSERT INTO Produs_Ingrediente VALUES
(32,11,100),(32,12,5),(32,13,40),(32,32,50),(32,16,20),(32,17,50),(32,26,10),(32,25,15),(32,20,10),(32,21,5),(32,22,15);

-- Yuki (33): foi soia,crema branza,ardei dulce,ton,somon,avocado,salata iceberg,castravete,alge chuka,sos nuci,icre tobiko,sos unagi,ghimbir,wasabi,sos soia
INSERT INTO Produs_Ingrediente VALUES
(33,36,10),(33,13,40),(33,39,30),(33,28,40),(33,17,40),(33,24,30),(33,38,20),(33,16,20),(33,37,20),(33,57,15),(33,43,10),(33,25,15),(33,20,10),(33,21,5),(33,22,15);

-- Ebi Tempura (34): orez,nori,crema branza,creveti fierti,icre tobiko,avocado,sos unagi,ghimbir,wasabi,sos soia
INSERT INTO Produs_Ingrediente VALUES
(34,11,100),(34,12,5),(34,13,40),(34,33,50),(34,43,10),(34,24,30),(34,25,15),(34,20,10),(34,21,5),(34,22,15);

-- Basilico Salmon Tempura (35): orez,nori,crema branza,somon prajit,castravete,busuioc,panko,sos picant,sos unagi,ghimbir,wasabi,sos soia
INSERT INTO Produs_Ingrediente VALUES
(35,11,100),(35,12,5),(35,13,40),(35,35,60),(35,16,20),(35,41,10),(35,42,15),(35,26,10),(35,25,15),(35,20,10),(35,21,5),(35,22,15);

-- Salmon Tempura (36): orez,nori,crema branza,somon,icre tobiko,avocado,sos unagi,ghimbir,wasabi,sos soia
INSERT INTO Produs_Ingrediente VALUES
(36,11,100),(36,12,5),(36,13,40),(36,17,60),(36,43,10),(36,24,30),(36,25,15),(36,20,10),(36,21,5),(36,22,15);

-- Shiro Tempura (37): orez,nori,crema branza,creveti tempura,castravete,avocado,sos truffle aioli,sos picant,icre tobiko,sos unagi,ghimbir,wasabi,sos soia
INSERT INTO Produs_Ingrediente VALUES
(37,11,100),(37,12,5),(37,13,40),(37,31,50),(37,16,20),(37,24,30),(37,18,15),(37,26,10),(37,43,10),(37,25,15),(37,20,10),(37,21,5),(37,22,15);

-- Umami Tempura (38): nori,crema branza,somon,castravete,avocado,tartar tipar,ghimbir,wasabi,sos soia
INSERT INTO Produs_Ingrediente VALUES
(38,12,5),(38,13,40),(38,17,60),(38,16,20),(38,24,30),(38,44,40),(38,20,10),(38,21,5),(38,22,15);

-- Nigiri Salmon (39): orez,somon,ghimbir,wasabi,sos soia
INSERT INTO Produs_Ingrediente VALUES
(39,11,25),(39,17,20),(39,20,5),(39,21,3),(39,22,8);

-- Nigiri Seared Salmon (40): orez,somon,sos soia,sos truffle aioli,icre rosii,ghimbir,wasabi
INSERT INTO Produs_Ingrediente VALUES
(40,11,25),(40,17,20),(40,22,8),(40,18,10),(40,19,5),(40,20,5),(40,21,3);

-- Nigiri Tuna (41): orez,ton,ghimbir,wasabi,sos soia
INSERT INTO Produs_Ingrediente VALUES
(41,11,25),(41,28,20),(41,20,5),(41,21,3),(41,22,8);

-- Nigiri Seared Tuna (42): orez,ton,sos soia,sos truffle aioli,icre rosii,ghimbir,wasabi
INSERT INTO Produs_Ingrediente VALUES
(42,11,25),(42,28,20),(42,22,8),(42,18,10),(42,19,5),(42,20,5),(42,21,3);

-- Nigiri Shrimp (43): orez,creveti fierti,ghimbir,wasabi,sos soia
INSERT INTO Produs_Ingrediente VALUES
(43,11,25),(43,33,20),(43,20,5),(43,21,3),(43,22,8);

-- Nigiri Eel (44): nori,orez,tipar,sos unagi,icre tobiko,ghimbir,wasabi,sos soia
INSERT INTO Produs_Ingrediente VALUES
(44,12,3),(44,11,25),(44,27,20),(44,25,10),(44,43,5),(44,20,5),(44,21,3),(44,22,8);

-- Nigiri Seared Eel (45): orez,tipar,sos unagi,icre tobiko,ghimbir,wasabi,sos soia
INSERT INTO Produs_Ingrediente VALUES
(45,11,25),(45,27,20),(45,25,10),(45,43,5),(45,20,5),(45,21,3),(45,22,8);

-- Gunkan Salmon (46): nori,orez,tartar somon,ghimbir,wasabi,sos soia
INSERT INTO Produs_Ingrediente VALUES
(46,12,3),(46,11,20),(46,45,25),(46,20,5),(46,21,3),(46,22,8);

-- Gunkan Red Caviar (47): nori,orez,icre rosii,ghimbir,wasabi,sos soia
INSERT INTO Produs_Ingrediente VALUES
(47,12,3),(47,11,20),(47,19,15),(47,20,5),(47,21,3),(47,22,8);

-- Gunkan Shrimp (48): nori,orez,tartar creveti,ghimbir,wasabi,sos soia
INSERT INTO Produs_Ingrediente VALUES
(48,12,3),(48,11,20),(48,46,25),(48,20,5),(48,21,3),(48,22,8);

-- Gunkan Eel (49): nori,orez,tartar tipar,sos unagi,ghimbir,wasabi,sos soia
INSERT INTO Produs_Ingrediente VALUES
(49,12,3),(49,11,20),(49,44,25),(49,25,10),(49,20,5),(49,21,3),(49,22,8);

-- Gunkan Tobiko (50): nori,orez,icre tobiko,ghimbir,wasabi,sos soia
INSERT INTO Produs_Ingrediente VALUES
(50,12,3),(50,11,20),(50,43,15),(50,20,5),(50,21,3),(50,22,8);

-- Gunkan Chuka (51): nori,orez,sos nuci,alge chuka,ghimbir,wasabi,sos soia
INSERT INTO Produs_Ingrediente VALUES
(51,12,3),(51,11,20),(51,57,10),(51,37,20),(51,20,5),(51,21,3),(51,22,8);

-- Crunch Poke (52): orez,tipar,castravete,takuan,avocado,fulgi ton,sos unagi,seminte susan,praz prajit,sos soia
INSERT INTO Produs_Ingrediente VALUES
(52,11,150),(52,27,60),(52,16,30),(52,47,20),(52,24,40),(52,48,10),(52,25,20),(52,29,5),(52,49,10),(52,22,20);

-- Tempura Shrimp Poke (53): orez,mango,castravete,para kimchi,edamame,creveti tempura,sos sweet chili,seminte susan,rosii cherry,fulgi ton,sos soia
INSERT INTO Produs_Ingrediente VALUES
(53,11,150),(53,14,30),(53,16,30),(53,50,20),(53,51,30),(53,31,60),(53,52,20),(53,29,5),(53,53,20),(53,48,10),(53,22,20);

-- Malibu Poke (54): orez,mango,alge chuka,rosii cherry,porumb,ridiche,avocado,tartar creveti,sos unagi,seminte susan,sos soia
INSERT INTO Produs_Ingrediente VALUES
(54,11,150),(54,14,30),(54,37,20),(54,53,20),(54,54,20),(54,55,15),(54,24,40),(54,46,50),(54,25,20),(54,29,5),(54,22,20);

-- Philly Poke (55): orez,mango,edamame,rosii cherry,castravete,avocado,somon,sos ponzu,sos unagi,icre tobiko,sos soia
INSERT INTO Produs_Ingrediente VALUES
(55,11,150),(55,14,30),(55,51,30),(55,53,20),(55,16,30),(55,24,40),(55,17,60),(55,56,15),(55,25,20),(55,43,10),(55,22,20);

-- Fish Trio Poke (56): orez,mango,rosii cherry,avocado,alge chuka,somon,ton,creveti,avocado
INSERT INTO Produs_Ingrediente VALUES
(56,11,150),(56,14,30),(56,53,20),(56,24,50),(56,37,20),(56,17,50),(56,28,50),(56,15,50),(56,24,40);
GO
-- Fish Trio Poke (56): orez,mango,rosii cherry,avocado,alge chuka,somon,ton,creveti
INSERT INTO Produs_Ingrediente VALUES
(56,11,150),(56,14,30),(56,53,20),(56,24,90),(56,37,20),(56,17,50),(56,28,50),(56,15,50);
GO

USE MojitoDB;

-- Stergem datele de test in ordinea corecta
DELETE FROM Detalii_Vanzari WHERE id_produs IN (SELECT id FROM Produse WHERE id_categorie = 1);
DELETE FROM Vanzari WHERE id NOT IN (SELECT DISTINCT id_vanzare FROM Detalii_Vanzari);
DELETE FROM Produs_Ingrediente WHERE id_produs IN (SELECT id FROM Produse WHERE id_categorie = 1);
DELETE FROM Produse WHERE id_categorie = 1;
GO
USE MojitoDB;

-- ============================================================
-- Stergere produse europene vechi
-- ============================================================
DELETE FROM Produs_Ingrediente WHERE id_produs IN (SELECT id FROM Produse WHERE id_categorie = 1);
DELETE FROM Produse WHERE id_categorie = 1;

-- ============================================================
-- PRODUSE EUROPENE cu preturi realiste (MDL)
-- ============================================================
INSERT INTO Produse (nume, id_categorie, pret, gramaj, tip_scadere) VALUES
-- MIC DEJUN (100-145 MDL)
('Scrumble cu creveti si orez prajit',                1, 135.00, '350g', 'ingrediente'),
('Terci de ovaz cu mango si cocos',                   1, 100.00, '430g', 'ingrediente'),
('Terci de ovaz cu fructe uscate si miere',           1, 100.00, '430g', 'ingrediente'),
('Syrniki cu mango si sos vanilie',                   1, 120.00, '290g', 'ingrediente'),
('Syrniki cu smantana si gem de caise',               1, 110.00, '280g', 'ingrediente'),
('Shakshuka cu ou pocheat',                           1, 130.00, '350g', 'ingrediente'),
('Mic dejun englezesc',                               1, 145.00, '550g', 'ingrediente'),
('Omleta cu creveti si guacamole',                    1, 140.00, '380g', 'ingrediente'),
('Oua pocheat cu bacon',                              1, 130.00, '305g', 'ingrediente'),
('Oua pocheat cu somon si icre rosii',                1, 145.00, '340g', 'ingrediente'),
-- GUSTARI (140-700 MDL)
('Guacamole cu nachos',                               1, 145.00, '180g', 'ingrediente'),
('Fritto misto',                                      1, 280.00, '700g', 'ingrediente'),
('Tartare de somon cu guacamole si briosa',           1, 260.00, '250g', 'ingrediente'),
('Tartare de vita cu icre rosii si lipie de cartofi', 1, 320.00, '220g', 'ingrediente'),
('Set de gustari asiatice',                           1, 420.00, '900g', 'ingrediente'),
('Set de gustari',                                    1, 380.00, '710g', 'ingrediente'),
-- FINGER FOOD (140-280 MDL)
('Crunch Set',                                        1, 200.00, '680g', 'ingrediente'),
('Aripioare de pui BBQ cu cartofi prajiti',           1, 175.00, '550g', 'ingrediente'),
('Popcorn de pui cu cartofi prajiti',                 1, 150.00, '420g', 'ingrediente'),
('Creveti pane cu sos chili-mayo si cartofi',         1, 165.00, '350g', 'ingrediente'),
('Smash burger cu vita',                              1, 210.00, '580g', 'ingrediente'),
('Burger Cezar cu snitel de pui',                     1, 195.00, '480g', 'ingrediente'),
-- GARNITURI (55-120 MDL)
('Broccoli grill cu sos miere-mustar',                1,  85.00, '240g', 'ingrediente'),
('Conopida cu sos truffle',                           1,  95.00, '340g', 'ingrediente'),
('Orez jasmin pe lapte de cocos cu sos unagi',        1,  65.00, '215g', 'ingrediente'),
('Batata fries cu parmezan',                          1,  75.00, '186g', 'ingrediente'),
-- PESTE (220-340 MDL)
('File de dorada cu varza de Bruxelles si spanac',    1, 245.00, '320g', 'ingrediente'),
('Steak de somon in sos cremos cu icre rosii',        1, 280.00, '270g', 'ingrediente'),
('Steak de ton cu legume sotate si sos romesco',      1, 310.00, '385g', 'ingrediente'),
-- CARNE (140-340 MDL)
('Pui la cuptor cu cartofi in sos cremos',            1, 185.00, '540g', 'ingrediente'),
('Piept de pui cu legume sotate si sos cremos',       1, 160.00, '340g', 'ingrediente'),
('Medalion de vita cu piure si sos demi-glace',       1, 320.00, '310g', 'ingrediente'),
('Pepper steak cu cartofi zdrobiti si sos de piper',  1, 340.00, '465g', 'ingrediente'),
('Coaste de porc inabsite cu cartofi prajiti',        1, 195.00, '420g', 'ingrediente'),
('Muschi de porc la cuptor cu cartofi si ciuperci',   1, 175.00, '480g', 'ingrediente');
GO

-- ============================================================
-- INGREDIENTE noi pentru bucataria europeana
-- ============================================================
INSERT INTO Ingrediente (nume, unitate_masura) VALUES
('Oua de gaina',                'g'),   -- 58
('Smantana',                    'g'),   -- 59
('Lapte',                       'g'),   -- 60
('Unt',                         'g'),   -- 61
('Faina',                       'g'),   -- 62
('Zahar',                       'g'),   -- 63
('Sare',                        'g'),   -- 64
('Piper negru',                 'g'),   -- 65
('Ulei vegetal',                'g'),   -- 66
('Ulei de masline',             'g'),   -- 67
('Frisca',                      'g'),   -- 68
('Vin alb',                     'g'),   -- 69
('Usturoi',                     'g'),   -- 70
('Ceapa',                       'g'),   -- 71
('Fulgi de ovaz',               'g'),   -- 72
('Mango conservat',             'g'),   -- 73
('Fistic maruntit',             'g'),   -- 74
('Cocos maruntit',              'g'),   -- 75
('Merisoare uscate',            'g'),   -- 76
('Curmale',                     'g'),   -- 77
('Smochine',                    'g'),   -- 78
('Miere',                       'g'),   -- 79
('Syrniki 3x50g',               'g'),   -- 80
('Gem de caise',                'g'),   -- 81
('Capsune',                     'g'),   -- 82
('Zahar pudra',                 'g'),   -- 83
('Sos shakshuka',               'g'),   -- 84
('Vinete',                      'g'),   -- 85
('Branza de capra',             'g'),   -- 86
('Coriandru',                   'g'),   -- 87
('Busuioc proaspat',            'g'),   -- 88
('Patrunjel',                   'g'),   -- 89
('Paine',                       'g'),   -- 90
('Carnati de pui',              'g'),   -- 91
('Ciuperci champignon',         'g'),   -- 92
('Branza halumi',               'g'),   -- 93
('Bacon',                       'g'),   -- 94
('Spanac',                      'g'),   -- 95
('Fasole rosie conservata',     'g'),   -- 96
('Branza olandeza',             'g'),   -- 97
('Sos guacamole',               'g'),   -- 98
('Salsa de rosii',              'g'),   -- 99
('Paine de grau',               'g'),   -- 100
('Branza de capra moale',       'g'),   -- 101
('Mix de salata',               'g'),   -- 102
('Sos olandez',                 'g'),   -- 103
('Nachos',                      'g'),   -- 104
('Ceapa rosie',                 'g'),   -- 105
('Lime',                        'g'),   -- 106
('Piper chili',                 'g'),   -- 107
('Creveti 16/20',               'g'),   -- 108
('Cartofi prajiti',             'g'),   -- 109
('Sos chili-mayo',              'g'),   -- 110
('Lamaie',                      'g'),   -- 111
('Somon curatat',               'g'),   -- 112
('Paine briosa',                'g'),   -- 113
('Icre rosii',                  'g'),   -- 114
('Sos kimchi',                  'g'),   -- 115
('Vita tocata cotlet',          'g'),   -- 116
('Mustar american',             'g'),   -- 117
('Sos BBQ',                     'g'),   -- 118
('Branza cheddar',              'g'),   -- 119
('Castraveti murati',           'g'),   -- 120
('Pui aripioare marinate',      'g'),   -- 121
('Pui popcorn',                 'g'),   -- 122
('Creveti pane',                'g'),   -- 123
('Bulochka pentru burger',      'g'),   -- 124
('Pui file panat',              'g'),   -- 125
('Broccoli',                    'g'),   -- 126
('Sos truffle',                 'g'),   -- 127
('Ulei truffle',                'g'),   -- 128
('Orez jasmin',                 'g'),   -- 129
('Lapte de cocos',              'g'),   -- 130
('Batata fries',                'g'),   -- 131
('Parmezan',                    'g'),   -- 132
('File de dorada',              'g'),   -- 133
('Varza de Bruxelles',          'g'),   -- 134
('Sos beurre blanc',            'g'),   -- 135
('Steak de somon',              'g'),   -- 136
('Ton steak',                   'g'),   -- 137
('Fasole kenyiana',             'g'),   -- 138
('Sos romesco',                 'g'),   -- 139
('Pui intreg',                  'g'),   -- 140
('Cartofi',                     'g'),   -- 141
('Pui file',                    'g'),   -- 142
('Conopida',                    'g'),   -- 143
('Porumb bebi',                 'g'),   -- 144
('Vita vrezka medalion',        'g'),   -- 145
('Piure de cartofi',            'g'),   -- 146
('Sos demi-glace',              'g'),   -- 147
('Vita vrezka steak',           'g'),   -- 148
('Sos de piper',                'g'),   -- 149
('Coaste de porc',              'g'),   -- 150
('Mustar zernos',               'g'),   -- 151
('Muschi de porc',              'g'),   -- 152
('Maioneza',                    'g'),   -- 153
('Calamar',                     'g'),   -- 154
('Sos unagi european',          'g');   -- 155
GO

-- Stocuri initiale
INSERT INTO Stocuri (id_ingredient, cantitate_disponibila, cantitate_minima)
SELECT id, 3000, 300 FROM Ingrediente WHERE id BETWEEN 58 AND 155;
GO

-- Verificare ID-uri produse europene
SELECT id, nume FROM Produse WHERE id_categorie = 1 ORDER BY id;
GO

USE MojitoDB;

-- ============================================================
-- RETETE BUCATARIE EUROPEANA (Produs_Ingrediente)
-- ID produse: 92-126
-- ============================================================

-- 92: Scrumble cu creveti si orez prajit
INSERT INTO Produs_Ingrediente VALUES
(92,58,100),(92,66,15),(92,59,100),(92,68,15),(92,97,20),(92,61,10),(92,64,2),(92,108,55),(92,67,10),(92,155,5),(92,89,2);

-- 93: Terci de ovaz cu mango si cocos
INSERT INTO Produs_Ingrediente VALUES
(93,72,70),(93,60,150),(93,63,5),(93,61,10),(93,64,2),(93,73,50),(93,74,5),(93,75,10);

-- 94: Terci de ovaz cu fructe uscate si miere
INSERT INTO Produs_Ingrediente VALUES
(94,72,70),(94,60,150),(94,63,5),(94,61,10),(94,64,2),(94,76,30),(94,77,30),(94,78,30),(94,79,40),(94,74,5);

-- 95: Syrniki cu mango si sos vanilie
INSERT INTO Produs_Ingrediente VALUES
(95,80,150),(95,67,5),(95,73,25),(95,82,20),(95,74,5),(95,85,20);

-- 96: Syrniki cu smantana si gem de caise
INSERT INTO Produs_Ingrediente VALUES
(96,80,150),(96,67,5),(96,59,50),(96,81,50),(96,83,3),(96,85,20),(96,74,5);

-- 97: Shakshuka cu ou pocheat
INSERT INTO Produs_Ingrediente VALUES
(97,84,180),(97,58,100),(97,89,2),(97,64,2),(97,65,1),(97,85,80),(97,62,10),(97,86,5),(97,88,2),(97,87,2),(97,90,60);

-- 98: Mic dejun englezesc
INSERT INTO Produs_Ingrediente VALUES
(98,58,100),(98,91,150),(98,92,50),(98,96,60),(98,93,40),(98,94,60),(98,64,2),(98,65,1),(98,67,15),(98,95,25),(98,96,100),(98,87,2),(98,88,2),(98,89,2);

-- 99: Omleta cu creveti si guacamole
INSERT INTO Produs_Ingrediente VALUES
(99,58,90),(99,60,25),(99,64,2),(99,65,1),(99,97,30),(99,108,80),(99,102,30),(99,69,20),(99,67,15),(99,98,45),(99,99,45);

-- 100: Oua pocheat cu bacon
INSERT INTO Produs_Ingrediente VALUES
(100,100,60),(100,101,25),(100,102,10),(100,112,60),(100,94,40),(100,58,100),(100,103,25),(100,89,5);

-- 101: Oua pocheat cu somon si icre rosii
INSERT INTO Produs_Ingrediente VALUES
(101,100,60),(101,101,25),(101,102,10),(101,112,60),(101,112,50),(101,103,25),(101,114,10),(101,58,100);

-- 102: Guacamole cu nachos
INSERT INTO Produs_Ingrediente VALUES
(102,98,100),(102,105,5),(102,106,3),(102,87,2),(102,65,2),(102,107,3),(102,67,10),(102,104,40);

-- 103: Fritto misto
INSERT INTO Produs_Ingrediente VALUES
(103,154,85),(103,154,80),(103,126,40),(103,108,80),(103,109,120),(103,62,20),(103,64,2),(103,65,1),(103,110,50),(103,111,25);

-- 104: Tartare de somon cu guacamole si briosa
INSERT INTO Produs_Ingrediente VALUES
(104,112,80),(104,98,80),(104,67,5),(104,68,5),(104,113,50),(104,64,2),(104,114,5);

-- 105: Tartare de vita cu icre rosii si lipie de cartofi
INSERT INTO Produs_Ingrediente VALUES
(105,115,3),(105,64,2),(105,65,1),(105,68,5),(105,114,8),(105,116,140);

-- 106: Set de gustari asiatice
INSERT INTO Produs_Ingrediente VALUES
(106,109,120),(106,110,50),(106,154,80),(106,108,80),(106,111,25);

-- 107: Set de gustari
INSERT INTO Produs_Ingrediente VALUES
(107,116,95),(107,125,90),(107,123,95),(107,109,120),(107,110,50),(107,111,25);

-- 108: Crunch Set
INSERT INTO Produs_Ingrediente VALUES
(108,109,120),(108,97,130),(108,123,130),(108,110,50),(108,110,50);

-- 109: Aripioare de pui BBQ cu cartofi prajiti
INSERT INTO Produs_Ingrediente VALUES
(109,121,310),(109,118,60),(109,109,120),(109,64,2),(109,110,50),(109,115,5),(109,128,2);

-- 110: Popcorn de pui cu cartofi prajiti
INSERT INTO Produs_Ingrediente VALUES
(110,122,180),(110,109,120),(110,110,50);

-- 111: Creveti pane cu sos chili-mayo si cartofi
INSERT INTO Produs_Ingrediente VALUES
(111,123,130),(111,110,50),(111,109,120),(111,64,2);

-- 112: Smash burger cu vita
INSERT INTO Produs_Ingrediente VALUES
(112,124,60),(112,116,180),(112,117,20),(112,118,30),(112,94,60),(112,119,25),(112,71,10),(112,120,15),(112,109,120),(112,110,50);

-- 113: Burger Cezar cu snitel de pui
INSERT INTO Produs_Ingrediente VALUES
(113,124,60),(113,117,10),(113,125,95),(113,119,15),(113,102,25),(113,132,5),(113,109,120),(113,110,50);

-- 114: Broccoli grill cu sos miere-mustar
INSERT INTO Produs_Ingrediente VALUES
(114,126,200),(114,67,10),(114,64,2),(114,65,1),(114,79,15),(114,117,10),(114,128,2);

-- 115: Conopida cu sos truffle
INSERT INTO Produs_Ingrediente VALUES
(115,143,260),(115,67,5),(115,64,2),(115,65,1),(115,127,70),(115,128,2);

-- 116: Orez jasmin pe lapte de cocos cu sos unagi
INSERT INTO Produs_Ingrediente VALUES
(116,129,150),(116,130,25),(116,64,2),(116,155,10);

-- 117: Batata fries cu parmezan
INSERT INTO Produs_Ingrediente VALUES
(117,131,130),(117,64,2),(117,132,6),(117,110,50);

-- 118: File de dorada cu varza de Bruxelles si spanac
INSERT INTO Produs_Ingrediente VALUES
(118,133,140),(118,64,2),(118,65,1),(118,61,10),(118,134,50),(118,95,15),(118,135,80);

-- 119: Steak de somon in sos cremos cu icre rosii
INSERT INTO Produs_Ingrediente VALUES
(119,136,145),(119,114,8),(119,67,10),(119,64,2),(119,65,1),(119,68,68),(119,146,30);

-- 120: Steak de ton cu legume sotate si sos romesco
INSERT INTO Produs_Ingrediente VALUES
(120,137,165),(120,67,10),(120,64,2),(120,65,1),(120,134,75),(120,138,35),(120,139,85),(120,61,5),(120,95,15);

-- 121: Pui la cuptor cu cartofi in sos cremos
INSERT INTO Produs_Ingrediente VALUES
(121,140,265),(121,141,120),(121,67,10),(121,71,14),(121,92,30),(121,68,80),(121,64,2),(121,65,1),(121,95,15),(121,155,15);

-- 122: Piept de pui cu legume sotate si sos cremos
INSERT INTO Produs_Ingrediente VALUES
(122,142,140),(122,126,43),(122,143,43),(122,134,43),(122,144,43),(122,61,5),(122,67,10),(122,64,2),(122,65,1),(122,132,4);

-- 123: Medalion de vita cu piure si sos demi-glace
INSERT INTO Produs_Ingrediente VALUES
(123,146,110),(123,60,10),(123,61,10),(123,64,1),(123,145,125),(123,67,10),(123,65,2),(123,65,1),(123,147,40),(123,95,15);

-- 124: Pepper steak cu cartofi zdrobiti si sos de piper
INSERT INTO Produs_Ingrediente VALUES
(124,148,210),(124,64,3),(124,65,1),(124,67,10),(124,61,10),(124,149,68),(124,141,155),(124,95,15);

-- 125: Coaste de porc inabsite cu cartofi prajiti
INSERT INTO Produs_Ingrediente VALUES
(125,150,270),(125,155,20),(125,109,120),(125,64,2),(125,117,10),(125,151,10),(125,115,10);

-- 126: Muschi de porc la cuptor cu cartofi si ciuperci
INSERT INTO Produs_Ingrediente VALUES
(126,71,17),(126,141,180),(126,92,25),(126,152,140),(126,67,5),(126,64,2),(126,65,1),(126,70,5),(126,153,50),(126,97,30),(126,89,5);
GO

PRINT 'Retete bucatarie europeana inserate cu succes!';
GO

USE MojitoDB;

-- Fix 98: Mic dejun englezesc (rosii cherry duplicate)
DELETE FROM Produs_Ingrediente WHERE id_produs = 98 AND id_ingredient = 96;
INSERT INTO Produs_Ingrediente VALUES (98,96,160); -- combinat 60+100

-- Fix 101: Oua pocheat cu somon (somon duplicate)
DELETE FROM Produs_Ingrediente WHERE id_produs = 101 AND id_ingredient = 112;
INSERT INTO Produs_Ingrediente VALUES (101,112,110); -- combinat 60+50

-- Fix 103: Fritto misto (calamar duplicate)
DELETE FROM Produs_Ingrediente WHERE id_produs = 103 AND id_ingredient = 154;
INSERT INTO Produs_Ingrediente VALUES (103,154,165); -- combinat 85+80

-- Fix 108: Crunch Set (sos chili-mayo duplicate)
DELETE FROM Produs_Ingrediente WHERE id_produs = 108 AND id_ingredient = 110;
INSERT INTO Produs_Ingrediente VALUES (108,110,100); -- combinat 50+50

-- Fix 123: Medalion de vita (sare duplicate)
DELETE FROM Produs_Ingrediente WHERE id_produs = 123 AND id_ingredient = 65;
INSERT INTO Produs_Ingrediente VALUES (123,65,3); -- combinat 2+1
GO

PRINT 'Fix-uri aplicate cu succes!';
GO