---
name: carousel-aida-writer
description: Pisanje kompletnih Instagram carousel postova po AIDA principu (Attention, Interest, Desire, Action). Koristi ovaj skill UVEK kada korisnik traži carousel post, carousel sadržaj, carousel tekst, slide-ove za Instagram, karusel, "napiši mi carousel", "napravi carousel", "carousel o temi X", "Instagram carousel", "karusel post", "napiši slajdove", "carousel za Instagram", "edukativni carousel", "carousel za platformu", ili bilo šta što uključuje pisanje višestranog Instagram sadržaja. Takođe koristi kada korisnik pomene "AIDA post", "post po AIDA principu", "carousel sa hook-om i CTA", "napiši mi edukativni post za Instagram", ili kada planira sadržaj i treba mu kompletna struktura carousel-a sa tekstom za svaki slajd. Skill generiše kompletne carousel-e spremne za dizajn, sa tekstom, strukturom, napomenama za vizual i uputstvima za dizajnera. Koristi i kada korisnik traži batch carousel-e, serijal carousel-a, ili kada ima temu i želi da je pretvori u carousel format.
---

# Carousel AIDA Writer

Ovaj skill piše kompletne Instagram carousel postove po AIDA principu. Baziran je na dokazanom obrascu koji generiše visok engagement (24.000+ pregleda, 766 čuvanja, 211 deljenja, 206 novih pratilaca sa jednog posta).

---

## Dokazani obrazac: 8-slajdni AIDA carousel

Ovaj skill koristi strukturu koja je testirana i daje rezultate. Pre pisanja bilo kog carousel-a, pročitaj referencu `references/aida-structure.md` za detaljan breakdown svake faze i slajda.

Ukratko, struktura je:

| Slajd | AIDA faza | Funkcija | Cilj |
|---|---|---|---|
| 1 | **A** — Attention | Cover/Hook | Zaustavi scroll, izazovi radoznalost |
| 2 | **I** — Interest | Problem | Čitalac se prepozna, oseća bol |
| 3 | **I** — Interest | Rešenje (uvod) | Poveži problem sa konkretnim rešenjem |
| 4 | **D** — Desire | Šta konkretno | Pokaži detalje, specifikacije, listu |
| 5 | **D** — Desire | Praktičan primer | Pokaži realan screenshot/primer |
| 6 | **D** — Desire | Zašto je moćno | Produbi analogiju, pokaži širu sliku |
| 7 | **D** — Desire | Ko ima korist | Pokaži različite primene/persone |
| 8 | **A** — Action | CTA | Jasna akcija, link na resurs |

---

## Kako funkcioniše

Skill ima tri moda:

### 1. WRITE — Pisanje kompletnog carousel-a od nule
### 2. ANALYZE — Analiza postojećeg carousel-a
### 3. IMPROVE — Poboljšanje drafta carousel-a

Claude automatski detektuje mod:
- Korisnik daje temu → WRITE
- Korisnik daje postojeći carousel i pita za feedback → ANALYZE
- Korisnik daje draft i traži poboljšanje → IMPROVE

---

## Pre pisanja: Prikupi kontekst

| Parametar | Potrebno? | Default |
|---|---|---|
| **Tema** | ✅ Obavezno | — |
| **Ciljna publika** | Poželjno | Preduzetnici i kreatori |
| **Ton** | Poželjno | Edukativno-razgovoran |
| **CTA destinacija** | Poželjno | Link u bio |
| **Broj slajdova** | Opciono | 8 (optimalan) |
| **Jezik** | Poželjno | Srpski |
| **Brend/projekat** | Opciono | — |

Ako korisnik da samo temu, koristi default vrednosti i kreni odmah. Ne postavljaj više od 1-2 pitanja. Bolje je napisati carousel sa pretpostavkama pa iterirati.

---

## WRITE mod — Kompletno pisanje carousel-a

### Korak 1: Definiši AIDA okosnicu

Pre pisanja slajdova, definiši u jednoj rečenici za svaku fazu:

```
ATTENTION: [Koji hook zaustavlja scroll?]
INTEREST: [Koji problem/bol pogađa čitaoca?]
DESIRE: [Šta je rešenje i zašto je vredno?]
ACTION: [Šta tačno čitalac treba da uradi?]
```

### Korak 2: Napiši svaki slajd

Pročitaj `references/aida-structure.md` za detaljna pravila svakog slajda, a zatim napiši carousel koristeći ovaj format:

```
---
CAROUSEL: [Naslov/tema]
Broj slajdova: [8]
AIDA okosnica:
  A: [jedna rečenica]
  I: [jedna rečenica]
  D: [jedna rečenica]
  A: [jedna rečenica]
---

## Slajd 1 — COVER (Attention)
**Tekst na slajdu:** [veliki, boldovan tekst — max 12 reči]
**Vizual:** [opis vizuala — lična fotka, screenshot, ilustracija]
**Napomena za dizajn:** [boja pozadine, stil, brend elementi]

## Slajd 2 — PROBLEM (Interest)
**Naslov:** [boldovan naslov — 2-4 reči]
**Body tekst:** [2-4 rečenice koje opisuju problem]
**Vizual:** [opis vizuala]

[... i tako za svaki slajd]

---
CAPTION:
[Tekst za caption ispod posta]

HASHTAGS:
[5-10 relevantnih hashtag-ova]
---
```

### Korak 3: Provera kvaliteta

Nakon pisanja, proveri svaki slajd po ovim kriterijumima (pročitaj `references/quality-checklist.md`):

1. **Jedna ideja po slajdu** — Nikad dve poruke na jednom slajdu
2. **Čitljivost** — Može li se pročitati za 3-5 sekundi?
3. **Vizuelna raznolikost** — Da li se slajdovi vizuelno razlikuju?
4. **Flow** — Da li svaki slajd prirodno vodi u sledeći?
5. **Hook snaga** — Da li bi cover slajd zaustavio scroll?
6. **CTA jasnoća** — Da li je potpuno jasno šta čitalac treba da uradi?
7. **Analogija** — Da li carousel koristi bar jednu jaku analogiju?
8. **Proof** — Da li postoji bar jedan slajd sa konkretnim primerom/dokazom?

---

## ANALYZE mod

Kada korisnik pošalje postojeći carousel za analizu:

### Scorecard (svaki kriterijum 1-5)

| Kriterijum | Opis | Ocena |
|---|---|---|
| **Hook/Cover** | Da li prvi slajd zaustavlja scroll? | /5 |
| **Problem-Solution fit** | Da li je problem jasan i rešenje logično? | /5 |
| **AIDA flow** | Da li prati AIDA strukturu? | /5 |
| **Jedna ideja/slajd** | Da li je svaki slajd fokusiran? | /5 |
| **Vizuelna raznolikost** | Da li se slajdovi razlikuju? | /5 |
| **Analogija/Proof** | Da li koristi analogije i/ili dokaze? | /5 |
| **CTA jasnoća** | Da li je CTA konkretan i motivišuć? | /5 |
| **Čitljivost** | Može li se svaki slajd pročitati za 3-5s? | /5 |
| **UKUPNO** | | /5 |

### Dijagnoza po slajdovima

Za svaki slajd napiši:
- Koja AIDA faza je (ili bi trebalo da bude)
- Šta radi dobro
- Šta bi poboljšao
- Konkretna alternativa (prepisan tekst)

---

## IMPROVE mod

1. Prvo uradi ANALYZE
2. Identifikuj najslabije tačke
3. Prepiši problematične slajdove
4. Predloži alternativne hook-ove za cover
5. Ponudi 2 varijante CTA slajda

---

## Pravila za pisanje carousel-a

### UVEK:

- **Analogije su tvoje najjače oružje.** Svaki carousel MORA imati bar jednu jaku analogiju (npr. "AI je kao nov zaposleni", "CLAUDE.md je priručnik za tvoju veštačku inteligenciju"). Analogija pretvara apstraktno u konkretno.
- **Cover slajd je 80% uspeha.** Ako cover ne zaustavi scroll, ostali slajdovi ne postoje. Uloži najviše vremena u hook.
- **Pokaži, ne pričaj.** Bar 1-2 slajda moraju imati konkretan primer, screenshot, ili realan prikaz. Ljudi veruju onom što vide.
- **Svaki slajd = jedna misao.** Ako trebaš dva paragrafa, trebaš dva slajda.
- **Tekst na slajdu mora biti čitljiv za 3-5 sekundi.** Ako je duži, skrati.
- **CTA mora biti specifičan.** "Link u bio" je bolje od "Prati me". "Na ludusvibe.com pokazujem kako" je bolje od "Link u bio".
- **Raznolikost slajdova.** Menjaj layout: tekst → tekst sa vizualom → lista → screenshot → grid kartica → CTA sa fotkom.
- **Caption dopunjuje, ne ponavlja.** Caption dodaje kontekst, ličnu priču ili pozadinu, ne prepričava slajdove.

### NIKAD:

- Generičan cover ("5 saveta za X" bez konteksta ili ugla)
- Svi slajdovi izgledaju isto (isti layout, ista boja)
- Previše teksta na jednom slajdu (max 50 reči po slajdu, idealno 20-35)
- CTA bez jasne destinacije ("pratite me" bez razloga zašto)
- Carousel bez analogije (suvoparno nabrajanje)
- Clickbait hook koji sadržaj ne ispunjava
- Više od 10 slajdova (optimalno 7-9, zlatna sredina je 8)
- Slajd bez jasne funkcije u AIDA strukturi

### BROJ SLAJDOVA:

| Dužina | Slajdovi | Kada koristiti |
|---|---|---|
| Kratak | 5-6 | Jednostavna tema, brz savet |
| Optimalan | 7-8 | Edukativni sadržaj, proces, tutorial |
| Dug | 9-10 | Kompleksna tema, dublja analiza |

Za kraće carousel-e, sažmi Desire fazu (slajdovi 4-7) na 2-3 slajda.

---

## Varijante AIDA strukture

### Varijanta A: Standardna (8 slajdova) — DEFAULT
Hook → Problem → Rešenje → Detalji → Primer → Zašto → Ko → CTA

### Varijanta B: Story-driven (8 slajdova)
Hook → "Bio sam u situaciji..." → "Probao sam X, Y..." → "Onda sam otkrio..." → Kako funkcioniše → Primer → Rezultat → CTA

### Varijanta C: Listicle (7 slajdova)
Hook/Naslov → Tačka 1 → Tačka 2 → Tačka 3 → Tačka 4 → Tačka 5 → CTA

### Varijanta D: Before/After (6 slajdova)
Hook → Bez ovoga (problem) → Sa ovim (rešenje) → Kako → Primer → CTA

Za detalje o svakoj varijanti, pročitaj `references/carousel-variants.md`.

---

## Srpski jezik — specifična pravila

- Prirodan govorni srpski, ne veštački prevodi
- Zarez (", ") umesto em crte (" — ") u svim tekstovima
- Anglicizmi samo ako su ustaljeni u tech/business zajednici (hook, carousel, CTA, AI, screenshot)
- Ti/Vi forma — konzistentno koristi onu koju korisnik preferira (default: Ti)
- Izbegavaj "U današnjem digitalnom svetu..." i slične AI klišee
- Piši kao da pričaš sa nekim — ne kao da držiš predavanje

---

## Output format

Uvek isporuči:
1. **AIDA okosnica** (4 rečenice)
2. **Svi slajdovi** sa tekstom, vizual napomenama i dizajn uputstvima
3. **Caption** za ispod posta
4. **Hashtag-ovi** (5-10)
5. **Alternativni hook-ovi** (3 varijante za cover slajd)

Za brze zahteve ("napiši carousel o X") — ne traži dodatne informacije, napiši odmah sa default parametrima i ponudi iteraciju.
