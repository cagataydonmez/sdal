-- ----------------------------------------------------------
-- MDB Tools - A library for reading MS Access database files
-- Copyright (C) 2000-2011 Brian Bruns and others.
-- Files in libmdb are licensed under LGPL and the utilities under
-- the GPL, see COPYING.LIB and COPYING files respectively.
-- Check out http://mdbtools.sourceforge.net
-- ----------------------------------------------------------

-- That file uses encoding UTF-8

CREATE TABLE `album_foto`
 (
	`id`			INTEGER, 
	`dosyaadi`			varchar, 
	`katid`			varchar, 
	`baslik`			varchar, 
	`aciklama`			TEXT, 
	`aktif`			INTEGER, 
	`ekleyenid`			varchar, 
	`tarih`			DateTime, 
	`hit`			INTEGER
	, PRIMARY KEY (`id`)
);

-- CREATE INDEXES ...

CREATE TABLE `album_fotoyorum`
 (
	`id`			INTEGER, 
	`fotoid`			varchar, 
	`uyeadi`			varchar, 
	`yorum`			TEXT, 
	`tarih`			DateTime
	, PRIMARY KEY (`id`)
);

-- CREATE INDEXES ...

CREATE TABLE `album_kat`
 (
	`id`			INTEGER, 
	`kategori`			varchar, 
	`aciklama`			TEXT, 
	`ilktarih`			DateTime, 
	`sonekleme`			DateTime, 
	`sonekleyen`			varchar, 
	`aktif`			INTEGER
	, PRIMARY KEY (`id`)
);

-- CREATE INDEXES ...

CREATE TABLE `filtre`
 (
	`id`			INTEGER, 
	`kufur`			varchar
	, PRIMARY KEY (`id`)
);

-- CREATE INDEXES ...

CREATE TABLE `gelenkutusu`
 (
	`id`			INTEGER, 
	`kime`			varchar, 
	`kimden`			varchar, 
	`aktifgelen`			INTEGER, 
	`konu`			varchar, 
	`mesaj`			TEXT, 
	`yeni`			INTEGER, 
	`tarih`			DateTime, 
	`aktifgiden`			INTEGER
	, PRIMARY KEY (`id`)
);

-- CREATE INDEXES ...

CREATE TABLE `mesaj`
 (
	`id`			INTEGER, 
	`gonderenid`			INTEGER, 
	`mesaj`			TEXT, 
	`tarih`			DateTime, 
	`kategori`			INTEGER
	, PRIMARY KEY (`id`)
);

-- CREATE INDEXES ...

CREATE TABLE `mesaj_kategori`
 (
	`id`			INTEGER, 
	`kategoriadi`			varchar, 
	`aciklama`			TEXT
	, PRIMARY KEY (`id`)
);

-- CREATE INDEXES ...

CREATE TABLE `oyun_yilan`
 (
	`id`			INTEGER, 
	`isim`			varchar, 
	`skor`			INTEGER, 
	`tarih`			DateTime
	, PRIMARY KEY (`id`)
);

-- CREATE INDEXES ...

CREATE TABLE `sayfalar`
 (
	`id`			INTEGER, 
	`sayfaismi`			varchar, 
	`sayfaurl`			varchar, 
	`hit`			INTEGER, 
	`sontarih`			DateTime, 
	`sonuye`			TEXT, 
	`babaid`			INTEGER, 
	`menugorun`			INTEGER, 
	`yonlendir`			INTEGER, 
	`sayfametin`			TEXT, 
	`mozellik`			INTEGER, 
	`resim`			varchar, 
	`sonip`			varchar
	, PRIMARY KEY (`id`)
);

-- CREATE INDEXES ...

CREATE TABLE `uyeler`
 (
	`id`			INTEGER, 
	`kadi`			varchar, 
	`sifre`			varchar, 
	`isim`			varchar, 
	`soyisim`			varchar, 
	`aktivasyon`			varchar, 
	`email`			varchar, 
	`aktiv`			INTEGER, 
	`yasak`			INTEGER, 
	`ilkbd`			INTEGER, 
	`websitesi`			varchar, 
	`imza`			TEXT, 
	`meslek`			varchar, 
	`sehir`			varchar, 
	`mailkapali`			INTEGER, 
	`hit`			INTEGER, 
	`ilksayfa`			INTEGER, 
	`mezuniyetyili`			varchar, 
	`universite`			varchar, 
	`dogumgun`			INTEGER, 
	`dogumay`			INTEGER, 
	`dogumyil`			INTEGER, 
	`sonislemtarih`			DateTime, 
	`sonislemsaat`			DateTime, 
	`online`			INTEGER, 
	`ilktarih`			DateTime, 
	`sontarih`			DateTime, 
	`admin`			INTEGER, 
	`sonip`			varchar, 
	`resim`			varchar, 
	`albumadmin`			INTEGER, 
	`hizliliste`			TEXT, 
	`s_sonislem`			DateTime, 
	`s_online`			INTEGER, 
	`oncekisontarih`			DateTime
	, PRIMARY KEY (`id`)
);

-- CREATE INDEXES ...



-- ----------------------------------------------------------
-- MDB Tools - A library for reading MS Access database files
-- Copyright (C) 2000-2011 Brian Bruns and others.
-- Files in libmdb are licensed under LGPL and the utilities under
-- the GPL, see COPYING.LIB and COPYING files respectively.
-- Check out http://mdbtools.sourceforge.net
-- ----------------------------------------------------------

-- That file uses encoding UTF-8

CREATE TABLE `hmes`
 (
	`id`			INTEGER, 
	`kadi`			varchar, 
	`metin`			varchar, 
	`tarih`			DateTime
	, PRIMARY KEY (`id`)
);

-- CREATE INDEXES ...



-- ----------------------------------------------------------
-- MDB Tools - A library for reading MS Access database files
-- Copyright (C) 2000-2011 Brian Bruns and others.
-- Files in libmdb are licensed under LGPL and the utilities under
-- the GPL, see COPYING.LIB and COPYING files respectively.
-- Check out http://mdbtools.sourceforge.net
-- ----------------------------------------------------------

-- That file uses encoding UTF-8

CREATE TABLE `oyun_tetris`
 (
	`id`			INTEGER, 
	`isim`			varchar, 
	`puan`			INTEGER, 
	`seviye`			INTEGER, 
	`satir`			INTEGER, 
	`tarih`			DateTime
	, PRIMARY KEY (`id`)
);

-- CREATE INDEXES ...



-- ----------------------------------------------------------
-- MDB Tools - A library for reading MS Access database files
-- Copyright (C) 2000-2011 Brian Bruns and others.
-- Files in libmdb are licensed under LGPL and the utilities under
-- the GPL, see COPYING.LIB and COPYING files respectively.
-- Check out http://mdbtools.sourceforge.net
-- ----------------------------------------------------------

-- That file uses encoding UTF-8

CREATE TABLE `takimlar`
 (
	`id`			INTEGER, 
	`tisim`			varchar, 
	`tkid`			INTEGER, 
	`tktelefon`			varchar, 
	`boyismi`			varchar, 
	`boymezuniyet`			varchar, 
	`ioyismi`			varchar, 
	`ioymezuniyet`			varchar, 
	`uoyismi`			varchar, 
	`uoymezuniyet`			varchar, 
	`doyismi`			varchar, 
	`doymezuniyet`			varchar, 
	`tarih`			DateTime
	, PRIMARY KEY (`id`)
);

-- CREATE INDEXES ...



