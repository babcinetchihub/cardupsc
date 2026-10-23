# CardUP — cardul de puncte al studenților UPSC

Aplicație web cu două părți:

- **index.html** — aplicația studentului: cont, card cu cod QR, evenimente, premii, istoric.
- **admin.html** — panoul angajaților: scanare cu camera, evenimente, premii, studenți, registru cu export în Excel.

Serverul este **Supabase** (bază de date PostgreSQL, autentificare, stocare fotografii). Nu trebuie scris sau întreținut cod de server: toată logica de puncte este în baza de date (`supabase-schema.sql`), iar paginile sunt fișiere statice care pot fi găzduite oriunde.

## Cum funcționează punctele

1. Studentul își face cont și primește automat un card cu număr unic (`UPSC-123456`) și cod QR.
2. La eveniment, angajatul alege evenimentul în panou și scanează cardul. Punctele intră pe card și studentul le vede imediat.
3. Studentul alege un premiu. Punctele se rezervă, stocul scade și primește un cod de ridicare (`R-ABC123`).
4. La Direcția Studenți, angajatul scanează codul, vede numele studentului și premiul, apasă „Confirmă predarea”. Punctele se retrag definitiv.
5. Fiecare operațiune rămâne în **registru**: data și ora, student, card, facultate, premiu sau eveniment, puncte, angajatul care a scanat.

Reguli de siguranță din baza de date: studentul nu își poate modifica punctele, rolul sau numărul cardului; un student nu primește de două ori punctele pentru același eveniment; un cod de ridicare se folosește o singură dată; doar angajații văd datele altor studenți.

## Instalare (aproximativ 30 de minute)

### 1. Proiectul Supabase
1. Creează un cont pe https://supabase.com și un proiect nou. Alege regiunea **Frankfurt (eu-central-1)**, cea mai apropiată de Moldova.
2. Deschide **SQL Editor**, lipește tot conținutul din `supabase-schema.sql` și apasă **Run**.
3. Opțional: rulează și `supabase-seed.sql` pentru evenimentele și premiile de pornire.

### 2. Autentificarea
În **Authentication → URL Configuration**:
- **Site URL**: adresa unde publici aplicația (de exemplu `https://cardup.upsc.md`).
- **Redirect URLs**: adaugă aceeași adresă cu `/index.html`.

În **Authentication → Providers → Email** lasă activă confirmarea emailului. Pentru un număr mare de studenți, configurează un server SMTP propriu (de exemplu cel al universității) în **Authentication → Emails → SMTP Settings**, deoarece serverul de email implicit are o limită mică de mesaje pe oră.

### 3. Configurarea paginilor
În **Project Settings → API** copiază **Project URL** și cheia **anon public** în `config.js`. Cheia anon este publică prin design; datele sunt protejate de regulile din `schema.sql`. Nu pune niciodată cheia `service_role` în fișiere.

### 4. Publicarea
Paginile trebuie să fie pe **HTTPS**, altfel camera nu pornește la scanare. Variante simple:
- **Netlify** (https://app.netlify.com/drop): tragi folderul în pagină și primești o adresă.
- Serverul universității: copiezi fișierele într-un subdomeniu, de exemplu `cardup.upsc.md`.

### 5. Primul administrator
1. Deschide `index.html` și creează-ți contul obișnuit.
2. În Supabase → SQL Editor rulează (cu emailul tău):
   ```sql
   update public.profiles set role = 'admin'
   where id = (select id from auth.users where email = 'emailul.tau@upsc.md');
   ```
3. Intră în `admin.html`. De acum poți da rolul de **Angajat** altor colegi din secțiunea „Studenți”, fără SQL.

## Verificare înainte de lansare
Testează cu două conturi (un student și un angajat):
- [ ] Studentul se înregistrează, confirmă emailul și vede cardul cu cod QR.
- [ ] Angajatul adaugă un eveniment cu fotografie; studentul îl vede.
- [ ] Angajatul scanează cardul cu telefonul; punctele apar la student fără reîncărcare.
- [ ] A doua scanare pentru același eveniment este refuzată.
- [ ] Studentul alege un premiu și primește codul; soldul scade cu punctele rezervate.
- [ ] Angajatul scanează codul, confirmă predarea; la student apare „Premiu ridicat”.
- [ ] A doua scanare a aceluiași cod este refuzată.
- [ ] Registrul arată operațiunile, iar exportul CSV se deschide corect în Excel.
- [ ] Un student care deschide `admin.html` vede mesajul „Nu ai acces la panou”.

## Protecția datelor
Aplicația prelucrează date personale (nume, facultate, email, activități). În Republica Moldova se aplică Legea nr. 133/2011 privind protecția datelor cu caracter personal. Înainte de lansare, stabiliți cu juristul universității textul informării pentru studenți și termenul de păstrare a datelor. Formularul de înregistrare cere deja acordul studentului.

## Costuri
Planul gratuit Supabase ajunge pentru un proiect-pilot. Verifică limitele actuale pe https://supabase.com/pricing. Planul gratuit oprește proiectul după o perioadă fără activitate, deci pentru utilizare permanentă este recomandat planul plătit.

## Structura fișierelor
```
index.html          aplicația studentului
admin.html          panoul administratorului
styles.css          aspectul comun
shared.js           funcții comune
config.js           adresa și cheia proiectului Supabase (de completat)
supabase-schema.sql baza de date, regulile de securitate și operațiunile
supabase-seed.sql   evenimente și premii de pornire (opțional)
logo-upsc-*.png, mark-upsc-*.png, favicon.png   sigla UPSC
```
