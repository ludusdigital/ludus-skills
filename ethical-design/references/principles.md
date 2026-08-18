# Etički principi dizajna — Kompletna referenca

## I. TRANSPARENTNOST

### 1. Jasnoća namere
Svaka akcija u interfejsu mora jasno komunicirati posledicu.
- Dugme "Nastavi" znači "nastavi", ne "upravo si se pretplatio"
- Hover/tooltip objašnjava šta će se desiti kad korisnik klikne
- Link koji vodi na eksterni sajt mora biti označen (ikonica ili tekst)

**Implementacija:**
```tsx
// LOŠE
<button>Nastavi</button>

// DOBRO
<button>Nastavi na plaćanje — 29€/mesečno</button>

// LOŠE
<a href="/external">Pogledaj</a>

// DOBRO
<a href="/external" target="_blank" rel="noopener">
  Pogledaj na partnerskm sajtu ↗
</a>
```

### 2. Transparentnost cena
- Puna cena vidljiva PRE checkout-a
- PDV/porez jasno naznačen
- Nema skrivenih "servisnih" naknada
- Jasno naznačiti da li je cena mesečna, godišnja ili jednokratna

**Implementacija:**
```tsx
// LOŠE: samo cifra
<span className="text-3xl font-bold">29€</span>

// DOBRO: pun kontekst
<div>
  <span className="text-3xl font-bold">29€</span>
  <span className="text-sm text-muted-foreground">/mesečno</span>
  <p className="text-xs text-muted-foreground mt-1">
    Uključuje PDV. Otkaži kad god želiš.
  </p>
</div>
```

### 3. Transparentnost podataka
- Jasno navesti KOJE podatke prikupljaš
- Objasniti ZAŠTO ih prikupljaš (konkretna svrha)
- Ponuditi stvaran izbor (ne samo "prihvati sve")
- Link ka privacy policy na SVAKOM formularu

### 4. Otvoreni algoritmi
Ako koristiš personalizaciju ili preporuke:
- Objasni ZAŠTO korisnik vidi određeni sadržaj
- Ponudi opciju za isključivanje personalizacije
- Ne sakrivaj da koristiš algoritam

---

## II. AUTONOMIJA KORISNIKA

### 5. Simetričnost ulaska i izlaska
Ako se korisnik može pretplatiti u 2 klika, mora moći da otkaže u 2 klika.

**Implementacija:**
```tsx
// Pretplata: 2 koraka
// 1. Klik na "Pretplati se"
// 2. Potvrda plaćanja

// Otkazivanje: ISTO 2 koraka
// 1. Klik na "Otkaži pretplatu" (vidljivo u dashboard-u)
// 2. Potvrda otkazivanja

// NIKAD:
// - Sakriven link za otkazivanje
// - "Nazovite nas da otkažete"
// - 5-koračni "retention flow" pre otkazivanja
// - "Da li ste SIGURNI? Izgubićete SVE!"
```

### 6. Etički default-ovi
Podrazumevana podešavanja moraju favorizovati korisnika:
- Newsletter checkbox: ODČEKIRAN po defaultu
- Marketing email-ovi: opt-in, nikad opt-out
- Privatnost: maksimalna zaštita po defaultu
- Notifikacije: minimum po defaultu

```tsx
// LOŠE
<label>
  <input type="checkbox" defaultChecked />
  Šalji mi promocije
</label>

// DOBRO
<label>
  <input type="checkbox" />
  Želim da primam korisne savete email-om (max 2x mesečno)
</label>
```

### 7. Pravo na "Ne" bez posledica
- Odbijanje ponude ne sme doneti negativne posledice
- Nema confirmshaming-a
- Nema blokiranja sadržaja kao kazna za odbijanje
- "Ne hvala" je uvek validna opcija

### 8. Kontrola nad iskustvom
Korisnik mora moći da prilagodi:
- Frekvenciju email-ova
- Tip notifikacija
- Nivo personalizacije
- Vidljivost profila

---

## III. POŠTENJE U KOMUNIKACIJI

### 9. Nema lažne hitnosti
Zabranjeni obrasci:
- Tajmeri koji se resetuju kad osvežiš stranicu
- "Ponuda ističe za 3 sata" koja traje mesecima
- "Još samo 2 mesta" kad nema ograničenja

Dozvoljeno:
- Stvarna deadline ponuda sa realnim datumom isteka
- Realno ograničeni kapaciteti (npr. živih radionica)

### 10. Nema lažnog socijalnog dokaza
Zabranjeni obrasci:
- "Marko iz Niša upravo kupio" (izmišljeno)
- Fake recenzije ili napumpani brojevi
- "1.247 ljudi trenutno gleda" (neistinito)

Dozvoljeno:
- Realni testimonijali sa imenom, prezimenom, kontekstom
- Tačan broj korisnika/polaznika (ažuriran)
- Screenshot realne komunikacije (sa dozvolom)

**Implementacija testimonijala:**
```tsx
// LOŠE: anonimno i sumnjivo
<blockquote>
  "Ovo je promenilo moj život!" — M.P.
</blockquote>

// DOBRO: realno i verifikovano
<blockquote>
  <p>"Posle 3 meseca primene, organski reach mi je porastao 40%."</p>
  <footer>
    <cite>Marija Petrović, vlasnica @marija_handmade</cite>
    <time dateTime="2025-11">novembar 2025</time>
  </footer>
</blockquote>
```

### 11. Nema emocionalne manipulacije
- Inspiracija DA, manipulacija strahom NE
- "Pogledaj rezultate naših polaznika" — DA
- "Tvoji konkurenti napreduju dok ti stagniraš" — NE
- Poziv na akciju iz pozicije mogućnosti, ne iz pozicije straha

### 12. Jasno razdvajanje sadržaja i reklame
- Plaćeni sadržaj UVEK označen
- Affiliate linkovi označeni
- Sponzorstva transparentna

---

## IV. INKLUZIVNOST I PRISTUPAČNOST

### 13. Dizajn za sve nivoe pismenosti
- Jednostavan jezik, bez žargona
- Jasna vizuelna hijerarhija
- Konzistentna navigacija
- Tooltip-ovi za složenije pojmove

### 14. Pristupačnost (WCAG 2.1 AA minimum)
- Kontrast: 4.5:1 za normalan tekst, 3:1 za veliki tekst
- Focus visible na SVIM interaktivnim elementima
- Skip to content link
- ARIA labele za dinamičke elemente
- Alt-text za sve funkcionalne slike
- Minimum 16px za body tekst
- Touch target minimum 44x44px na mobilnom

```tsx
// Focus stilovi — NIKAD ne sakrivaj, nego stilizuj
// LOŠE
*:focus { outline: none; }

// DOBRO (Tailwind)
// focus-visible:ring-2 focus-visible:ring-offset-2 focus-visible:ring-primary
```

### 15. Jezička jasnoća
- Terms of Service: kratak human-readable rezime na vrhu
- Privacy Policy: konkretne svrhe, ne pravnički žargon
- Error poruke: konkretne i pomoćne

---

## V. DOBROBIT KORISNIKA

### 16. Poštuj vreme
- Jasna struktura, laka navigacija
- Bez "beskonačnog scroll-a" koji je dizajniran da zarobi korisnika
- Progress indikatori za dugačke procese
- Jasno koliko vremena zahteva svaka akcija

### 17. Ne monetizuj FOMO
```tsx
// LOŠE: kreiranje anksioznosti
<p className="text-red-500 font-bold animate-pulse">
  ⚠️ Pretplata ističe SUTRA! Izgubićeš pristup SVEMU!
</p>

// DOBRO: informativno i mirno
<div className="p-4 bg-amber-50 border border-amber-200 rounded-lg">
  <p>Tvoja pretplata se obnavlja 15. aprila.</p>
  <a href="/settings/subscription">Upravljaj pretplatom →</a>
</div>
```

### 18. Etičko korišćenje psihologije
Dozvoljeno (u interesu korisnika):
- Reciprocitet: besplatan sadržaj koji gradi poverenje
- Social proof: realni testimonijali koji pomažu u odlučivanju
- Jasnoća: uprošćavanje kompleksnog izbora
- Konzistentnost: koherentno iskustvo kroz platformu

Zabranjeno (protiv interesa korisnika):
- Lažna oskudica za kreiranje panike
- Ankering na nerealnu "originalnu cenu"
- Confirmshaming za zadržavanje korisnika
- Dark patterns za sakrivanje opcija

---

## VI. ODGOVORNOST I MERENJE

### 19. Etički KPI-jevi
Pored konverzije i revenue-a, meri:
- Churn razlog (zašto korisnici odlaze)
- Customer satisfaction (NPS, CSAT)
- Stopa refund-ova (visoka stopa = problem)
- Time to value (koliko brzo korisnik dobija vrednost)
- Support ticket volume (visok = konfuzan UX)

### 20. Etička revizija
Periodično proveri:
- Prođi kroz proizvod kao potpuno nov korisnik
- Testiraj sa korisnikom niske digitalne pismenosti
- Proveri sve default-ove — da li favorizuju korisnika?
- Pregledaj sve microcopy — da li je manipulativan?

### 21. Feedback petlja
- Omogući lak feedback na SVAKOJ stranici
- Reaguj na negativan feedback
- Budi transparentan o promenama koje praviš na osnovu feedback-a