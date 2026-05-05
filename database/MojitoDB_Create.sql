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