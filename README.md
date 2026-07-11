# Template Docker per Laravel

Questo template serve per preparare rapidamente un nuovo progetto Laravel con:

- PHP-FPM
- Nginx
- MariaDB
- phpMyAdmin
- Composer
- Node.js e npm

Il nome del progetto Docker e i dati del database vengono ricavati automaticamente dal nome della cartella Laravel.

---

## File del template

Copia nella cartella principale del progetto Laravel questi elementi:

```text
Dockerfile
docker-compose.yml
setup-docker.sh
docker-configs/
└── nginx/
    └── app.conf
```

La cartella principale del progetto è quella che contiene anche:

```text
artisan
composer.json
.env.example
```

Esempio:

```text
/home/alex/Web-Projects/eiss-comuni/
```

---

## 1. Creare il progetto Laravel

Dalla cartella che contiene i progetti:

```bash
cd ~/Web-Projects
```

Creare il nuovo progetto:

```bash
laravel new nome-progetto --phpunit --git --no-node --no-interaction
```

Entrare nella nuova cartella:

```bash
cd nome-progetto
```

Usare preferibilmente nomi tutti minuscoli separati da trattini:

```text
eiss-comuni
gestione-clienti
portale-tributi
```

---

## 2. Copiare il template dal NAS

Copiare nella radice del progetto i file conservati sul NAS.

Esempio generico:

```bash
cp -a /percorso/del/nas/laravel-docker-template/. .
```

Il `/.` finale copia tutto il contenuto del template, comprese le sottocartelle, senza creare una cartella annidata.

Dopo la copia, nella cartella Laravel devono essere presenti:

```text
Dockerfile
docker-compose.yml
setup-docker.sh
docker-configs/nginx/app.conf
```

---

## 3. Rendere eseguibile lo script

Da fare dopo aver copiato lo script in un nuovo progetto:

```bash
chmod +x setup-docker.sh
```

---

## 4. Avvio standard

Per usare:

- nome del progetto ricavato dalla cartella;
- PHP 8.5;
- database derivato automaticamente dal nome;

eseguire:

```bash
./setup-docker.sh
```

Esempio, nella cartella:

```text
eiss-comuni
```

verranno impostati:

```text
Progetto Docker: eiss-comuni
Database:        eiss_comuni_db
Utente DB:       eiss_comuni_user
Password DB:     eiss_comuni_pass
PHP:             8.5
```

---

## 5. Scegliere una versione PHP diversa

Per usare PHP 8.4:

```bash
./setup-docker.sh 8.4
```

Per usare PHP 8.5:

```bash
./setup-docker.sh 8.5
```

La versione predefinita, quando non viene indicata, è PHP 8.5.

Lo script aggiorna il file `.env`; il `Dockerfile` e il `docker-compose.yml` leggono la versione tramite la variabile:

```env
PHP_VERSION=8.5
```

---

## 6. Indicare manualmente il nome del progetto

Normalmente non serve, perché il nome viene preso dalla cartella.

Per forzare un nome diverso:

```bash
./setup-docker.sh --name nome-progetto
```

Per indicare sia nome sia versione PHP:

```bash
./setup-docker.sh --name nome-progetto --php 8.5
```

È disponibile anche la forma posizionale:

```bash
./setup-docker.sh nome-progetto 8.5
```

Conviene comunque lasciare che il nome venga ricavato dalla cartella, così cartella, progetto Docker e database restano coerenti.

---

## 7. Configurare senza avviare Docker

Per aggiornare soltanto il file `.env` e validare la configurazione:

```bash
./setup-docker.sh --no-start
```

Non vengono costruiti né avviati i container.

---

## 8. Ripartire con un database vuoto

Solo per un progetto nuovo o quando si vuole cancellare volontariamente tutto il database:

```bash
./setup-docker.sh --fresh-db
```

**Attenzione:** questa opzione elimina il volume MariaDB del progetto e tutti i dati contenuti.

Non usarla su un progetto con dati da conservare.

---

## 9. Cosa fa lo script

Lo script:

1. verifica di trovarsi nella cartella principale di Laravel;
2. ricava il nome del progetto dalla cartella;
3. normalizza il nome in minuscolo con trattini;
4. crea nome, utente e password del database;
5. crea `.env` da `.env.example` se manca;
6. imposta PHP e le variabili Docker nel `.env`;
7. imposta la connessione Laravel a MariaDB;
8. valida `docker-compose.yml`;
9. costruisce il container PHP;
10. avvia PHP-FPM, Nginx, MariaDB e phpMyAdmin;
11. esegue `composer install`;
12. genera `APP_KEY` se manca;
13. esegue `npm install` se esiste `package.json` e manca `node_modules`;
14. controlla PHP, Nginx e lo stato dei container.

Le migrazioni non vengono eseguite automaticamente.

---

## 10. Eseguire le migrazioni

Quando il progetto e il database sono pronti:

```bash
docker compose exec web php artisan migrate
```

---

## 11. Indirizzi locali

Sito Laravel:

```text
http://localhost
```

phpMyAdmin:

```text
http://localhost:8080
```

Dati di collegamento interni Laravel:

```env
DB_CONNECTION=mysql
DB_HOST=db
DB_PORT=3306
```

---

## 12. Comandi utili

Vedere lo stato dei container:

```bash
docker compose ps
```

Controllare la versione PHP del container:

```bash
docker compose exec web php -v
```

Controllare i moduli PHP caricati:

```bash
docker compose exec web php -m
```

Controllare la configurazione Nginx:

```bash
docker compose exec nginx nginx -t
```

Aprire una shell nel container PHP:

```bash
docker compose exec web bash
```

Vedere i log:

```bash
docker compose logs -f
```

Vedere soltanto i log di Laravel/PHP:

```bash
docker compose logs -f web
```

Vedere soltanto i log Nginx:

```bash
docker compose logs -f nginx
```

Fermare il progetto senza cancellare il database:

```bash
docker compose down
```

Riavviare il progetto:

```bash
docker compose up -d
```

Ricostruire il container PHP dopo una modifica al Dockerfile:

```bash
docker compose build --no-cache --pull web
docker compose up -d
```

---

## 13. Aggiornare solo Nginx

Il file Nginx si trova in:

```text
docker-configs/nginx/app.conf
```

Essendo montato come volume, normalmente non serve ricostruire PHP.

Dopo una modifica:

```bash
docker compose exec nginx nginx -t
docker compose restart nginx
```

---

## 14. Aggiungere Filament

Dopo che Docker è attivo:

```bash
docker compose exec web composer require filament/filament
docker compose exec web php artisan filament:install --panels
docker compose exec web php artisan migrate
docker compose exec web php artisan make:filament-user
```

---

## 15. Aggiungere Livewire

```bash
docker compose exec web composer require livewire/livewire
```

---

## 16. Regola per la versione PHP

Per un progetto nuovo usare normalmente:

```text
PHP 8.5
```

Usare una versione diversa quando il server di produzione richiede esplicitamente quella versione.

L'ambiente locale dovrebbe restare il più possibile coerente con il server online.

---

## Procedura rapida riassunta

```bash
cd ~/Web-Projects

laravel new nome-progetto --phpunit --git --no-node --no-interaction

cd nome-progetto

cp -a /percorso/del/nas/laravel-docker-template/. .

chmod +x setup-docker.sh

./setup-docker.sh

docker compose exec web php artisan migrate
```
