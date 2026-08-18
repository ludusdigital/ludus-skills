# Dark Patterns — Šta NIKAD ne implementirati

Ovo je checklist manipulativnih obrazaca koje MORAŠ da izbegneš u svakom interfejsu.
Za svaki anti-pattern dat je opis, primer, i etička alternativa.

---

## 1. Confirmshaming

**Šta je:** Korišćenje krivice ili srama da se korisnik odvrati od odbijanja ponude.

**Prepoznaj:**
```
❌ "Ne, ne želim da unapredim svoj biznis"
❌ "Nastavi bez popusta (znam da gubim)"
❌ Tužna maskota/emoji kad korisnik odbije
```

**Etička alternativa:**
```
✅ "Ne, hvala"
✅ "Preskoči" / "Možda kasnije"
✅ Neutralan ton bez emocionalne manipulacije
```

---

## 2. Roach Motel (lak ulaz, težak izlaz)

**Šta je:** Registracija/pretplata u 2 klika, otkazivanje traži 10 koraka.

**Prepoznaj:**
```
❌ Dugme "Pretplati se" prominentno, "Otkaži" sakriveno
❌ "Pozovite nas za otkazivanje" (nema online opcije)
❌ 5-koračni retention flow pre otkazivanja
❌ "Jeste li sigurni?" → "ZAISTA sigurni?" → "Poslednja šansa!" → ...
```

**Etička alternativa:**
```
✅ "Otkaži pretplatu" dugme u Settings, vidljivo i jasno
✅ Maksimalno 2 koraka: klik → potvrda → gotovo
✅ Jedna kratka, informativna poruka: "Pristup traje do [datum]"
✅ Opcija za pauzu kao alternativa (ali ne umesto otkazivanja)
```

**Implementacija:**
```tsx
// Cancel flow — MAKSIMALNO ovako
function CancelSubscription() {
  return (
    <div>
      <h2>Otkaži pretplatu</h2>
      <p>Tvoj pristup ostaje aktivan do {expiryDate}.</p>
      <p>Možeš se ponovo pretplatiti kad god želiš.</p>
      <div className="flex gap-3 mt-4">
        <Button variant="outline" onClick={goBack}>
          Zadrži pretplatu
        </Button>
        <Button variant="destructive" onClick={handleCancel}>
          Potvrdi otkazivanje
        </Button>
      </div>
    </div>
  );
}
// NAPOMENA: Oba dugmeta iste vizuelne težine.
// "Zadrži" NIJE veće/prominentnije od "Otkaži".
```

---

## 3. Hidden Costs (skriveni troškovi)

**Šta je:** Cena raste tokom checkout-a jer se dodaju "takse", "naknade", "obrada".

**Prepoznaj:**
```
❌ Cena na landing page: 29€ → Checkout: 34.80€ (+ PDV + naknada za obradu)
❌ "Besplatna dostava" ali minimalna narudžbina 50€
❌ "Od 9€/mesečno" (ali samo na godišnjem planu za 10+ korisnika)
```

**Etička alternativa:**
```
✅ Finalna cena vidljiva od prvog trenutka
✅ "29€/mesečno (uklj. PDV)" — odmah na pricing stranici
✅ Jasna naznaka šta utiče na cenu (broj korisnika, period, itd.)
```

---

## 4. Forced Continuity (prisilni nastavak)

**Šta je:** Besplatan trial se automatski pretvara u plaćenu pretplatu bez jasnog upozorenja.

**Prepoznaj:**
```
❌ Trial zahteva karticu bez objašnjenja zašto
❌ Nema email-a pre završetka trial-a
❌ Prva naplata bez prethodne notifikacije
```

**Etička alternativa:**
```
✅ Trial BEZ kartice kad god je moguće
✅ Ako je kartica neophodna — jasno objasniti zašto i kada će biti naplaćena
✅ Email 3 dana i 1 dan pre isteka trial-a
✅ Jasan prikaz datuma prve naplate pri registraciji
```

---

## 5. Sneak into Basket (ubacivanje u korpu)

**Šta je:** Automatsko dodavanje proizvoda/usluga u korpu bez pristanka.

**Prepoznaj:**
```
❌ Pre-selektovani add-on u checkout-u
❌ "Osiguranje" automatski uključeno
❌ Donacija automatski dodata na iznos
```

**Etička alternativa:**
```
✅ Korpa sadrži SAMO ono što je korisnik eksplicitno dodao
✅ Add-on ponude kao jasna, odčekirana opcija
✅ Svaki item u korpi sa "Ukloni" dugmetom
```

---

## 6. Trick Questions (trik pitanja)

**Šta je:** Formulacije sa duplim negacijama ili kontra-intuitivnim checkboxovima.

**Prepoznaj:**
```
❌ "Odčekiraj ako NE želiš da NE primaš email-ove"
❌ Checkbox gde čekiranje znači odbijanje (obrnuto od očekivanog)
❌ "Da, ne želim popust" / "Ne, želim popust"
```

**Etička alternativa:**
```
✅ Jednostavna, pozitivna formulacija
✅ Čekiranje UVEK znači pristanak
✅ "Želim da primam email novosti" (odčekirano po defaultu)
```

---

## 7. Disguised Ads (maskirane reklame)

**Šta je:** Reklame koje izgledaju kao sadržaj ili UI elementi.

**Prepoznaj:**
```
❌ Reklama dizajnirana kao "Download" dugme
❌ Sponzorisani sadržaj bez oznake
❌ Affiliate link bez disclosure-a
```

**Etička alternativa:**
```
✅ Jasna "Sponzorisano" / "Reklama" oznaka
✅ Affiliate disclosure na vrhu stranice
✅ Vizuelno razdvajanje ads-a od sadržaja
```

---

## 8. False Urgency & Scarcity (lažna hitnost i oskudica)

**Šta je:** Izmišljeni tajmeri, lažni brojači, nepostojeća ograničenja.

**Prepoznaj:**
```
❌ Countdown timer koji se resetuje na refresh
❌ "Još samo 2 mesta!" (nema ograničenja)
❌ "37 osoba gleda ovaj proizvod" (izmišljeno)
❌ "Cena raste za 3h" (raste svaki dan iznova)
```

**Etička alternativa:**
```
✅ Ako postoji realan deadline — prikaži tačan datum, ne countdown
✅ Ako postoji realno ograničenje — budi transparentan o kapacitetu
✅ Nikad ne izmišljaj brojke o gledaocima ili kupovinama
```

**Implementacija:**
```tsx
// LOŠE
<div className="text-red-600 animate-pulse">
  🔥 Još samo {fakeCount} mesta! Požuri!
  <CountdownTimer resetsOnRefresh />
</div>

// DOBRO (ako je ograničenje realno)
<div className="text-muted-foreground">
  <p>Preostalo mesta: {realAvailableSeats} od {totalSeats}</p>
  <p>Registracija se zatvara {formatDate(realDeadline)}</p>
</div>
```

---

## 9. Privacy Zuckering

**Šta je:** Dizajn koji tera korisnika da podeli više podataka nego što želi.

**Prepoznaj:**
```
❌ "Prihvati sve" dugme veliko i zeleno, "Podesi" sivo i malo
❌ Pre-čekirani checkboxovi za marketing
❌ Zahtevanje podataka koji nisu neophodni za servis
❌ 47 klikova da se odbiju svi cookie-ji
```

**Etička alternativa:**
```
✅ "Prihvati" i "Odbij" iste vizuelne težine
✅ Granularna kontrola bez zatrpavanja
✅ Formulari traže SAMO neophodne podatke
✅ Jasan opis svrhe svakog podatka koji se traži
```

**Implementacija cookie consent-a:**
```tsx
// LOŠE — asimetrični dizajn
<div>
  <Button size="lg" variant="default">Prihvati sve</Button>
  <button className="text-xs text-gray-400 underline">podesi</button>
</div>

// DOBRO — simetrični dizajn
<div className="flex gap-3">
  <Button variant="outline">Samo neophodni</Button>
  <Button variant="outline">Podesi izbor</Button>
  <Button variant="default">Prihvati sve</Button>
</div>
// Sva tri dugmeta iste vizuelne težine
```

---

## 10. Obstruction (opstrukcija)

**Šta je:** Namerno otežavanje akcije koja ne ide u korist kompanije.

**Prepoznaj:**
```
❌ "Kontaktiraj podršku" umesto self-service opcije za brisanje naloga
❌ Sakriven "Eksportuj podatke" u meniju sa 5 nivoa dubine
❌ Refund forma koja zahteva 20 polja
```

**Etička alternativa:**
```
✅ Self-service za SVE korisničke akcije
✅ Brisanje naloga, export podataka, refund — sve dostupno u Settings
✅ Maksimalna jednostavnost za akcije koje korisnik želi da izvrši
```

---

## 11. Misdirection (preusmjeravanje)

**Šta je:** Dizajn koji namerno skreće pažnju sa jedne opcije na drugu.

**Prepoznaj:**
```
❌ "Besplatan" plan sitniji i manje uočljiv od premium plana
❌ X dugme za zatvaranje popup-a je 4px i jedva vidljivo
❌ "Preskoči" link iste boje kao pozadina
```

**Etička alternativa:**
```
✅ Sve opcije prikazane ravnopravno
✅ X/Close dugme jasno vidljivo i dovoljno veliko (min 44x44px)
✅ Navigacione opcije uvek jasno uočljive
```

---

## Kompletni checklist pre deploya

Pre svakog deploya, proveri da ne postoji nijedan od ovih obrazaca:

```
[ ] Confirmshaming — neutralan jezik pri odbijanju
[ ] Roach Motel — simetričan ulaz/izlaz
[ ] Hidden costs — puna cena vidljiva odmah
[ ] Forced continuity — jasno upozorenje pre naplate
[ ] Sneak into basket — korpa sadrži samo eksplicitno dodato
[ ] Trick questions — jasne formulacije, bez duplih negacija
[ ] Disguised ads — jasno označen plaćeni sadržaj
[ ] False urgency — bez lažnih tajmera i oskudice
[ ] Privacy zuckering — simetrične opcije za consent
[ ] Obstruction — sve akcije dostupne u self-service
[ ] Misdirection — sve opcije ravnopravno vidljive
```