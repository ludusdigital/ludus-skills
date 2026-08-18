---
name: ethical-design
description: Primeni etičke principe dizajna i komunikacije pri izgradnji landing stranica, SaaS platformi, checkout flow-ova, onboarding-a, pricing stranica, email sekvenci, cookie consent-a, subscription management-a i bilo kog korisničkog interfejsa. Koristi ovaj skill UVEK kada praviš bilo koji UI koji utiče na korisničke odluke — uključujući CTA dugmad, forme, modalne prozore, notifikacije, pricing tabele, testimonijale, onboarding korake, otkazivanje pretplata i GDPR/cookie banere. Takođe koristi kada korisnik pomene "etički dizajn", "bez manipulacije", "transparentan UX", "human-centered", "fair pricing", "čist checkout", ili kada traži landing page, platformu ili aplikaciju koja gradi poverenje. Ovaj skill se MORA koristiti zajedno sa frontend-design skillom za vizuelni kvalitet.
---

# Ethical Design & Communication Skill

Ovaj skill obezbeđuje da svaki UI koji napraviš poštuje korisnika, gradi poverenje i izbegava manipulativne obrasce (dark patterns). Etički dizajn nije ograničenje — to je konkurentska prednost koja gradi dugoročnu lojalnost.

## Fundamentalni principi

Svaki dizajn element mora proći kroz 4 testa pre implementacije:

1. **Test autonomije**: Da li korisnik donosi informisanu odluku?
2. **Test reverzibilnosti**: Da li korisnik može lako da poništi svoju odluku?
3. **Test transparentnosti**: Da li bi se korisnik osećao prevareno kad bi shvatio kako dizajn utiče na njega?
4. **Test asimetrije**: Da li dizajn stvara win-win ili favorizuje kompaniju na štetu korisnika?

Ako bilo koji od ovih testova pada — redizajniraj element.

## Obavezno čitanje pre implementacije

Pre nego što počneš sa kodom, pročitaj odgovarajuće reference fajlove:

- **Za sve UI projekte**: Pročitaj `references/principles.md` — kompletna lista etičkih principa
- **Za landing page, checkout, pricing, onboarding**: Pročitaj `references/anti-patterns.md` — dark patterns koje MORAŠ da izbegneš
- **Za bilo koji tekst (CTA, headline, microcopy, email)**: Pročitaj `references/copy-guidelines.md` — etička komunikacija i copywriting

## Workflow

### 1. Analiza konteksta
Pre kodiranja, definiši:
- Ko je ciljna publika? (nivo digitalne pismenosti, starosna grupa, kontekst)
- Koja je primarna akcija koju korisnik treba da izvrši?
- Koje informacije su korisniku POTREBNE da donese informisanu odluku?
- Gde su tačke potencijalne manipulacije u ovom flow-u?

### 2. Dizajn sa etičkim principima
Primeni principe iz `references/principles.md` na svaki element. Ključne oblasti:

**Pricing & Checkout:**
- Puna cena vidljiva ODMAH, nikad skriveni troškovi
- Jasno naznačiti šta je uključeno u svaki plan
- Poređenje planova mora biti pošteno, ne dizajnirano da "gura" ka skupljoj opciji
- Besplatni trial NIKAD ne zahteva karticu osim ako je to eksplicitno komunicirano

**Subscription Management:**
- Otkazivanje u maksimalno 2 klika
- Otkazivanje dostupno na istom mestu gde je i pretplata
- Jasan prikaz šta korisnik gubi i kada
- Bez "guilt trip" kopija pri otkazivanju

**Onboarding:**
- Progresivno otkrivanje — ne zatrpavaj korisnika
- Svaki korak ima jasnu vrednost za korisnika
- Opciono preskakanje svakog koraka koji nije kritičan
- Bez prisilnog davanja podataka koji nisu neophodni

**Cookie Consent & Privatnost:**
- "Prihvati" i "Odbij" vizuelno jednaki (ista veličina, ista prominentnost)
- Granularna kontrola bez zatrpavanja
- Bez pre-čekiranih checkboxova
- Jasan, human-readable opis svrhe svakog cookie-ja

**Social Proof & Testimonijali:**
- Samo realni testimonijali realnih korisnika
- Bez izmišljenih "X osoba trenutno gleda" notifikacija
- Bez lažnih countdown tajmera ili lažne oskudice
- Statistike moraju biti tačne i verifikovane

### 3. Implementacija microcopy-ja
Svaki tekst u interfejsu mora da prolazi kroz filter iz `references/copy-guidelines.md`:
- CTA dugmad: jasna akcija, ne vague "Saznaj više"
- Error poruke: konkretne, pomoćne, ne okrivljujuće
- Confirmation dijalozi: neutralan jezik, bez emotional manipulation
- Notifikacije: informativne, ne anksiozne

### 4. Accessibility kao temelj
Svaki element MORA biti pristupačan:
- Kontrast minimalno WCAG AA (4.5:1 za tekst, 3:1 za velike elemente)
- Fokus stanja za keyboard navigaciju
- ARIA labele za dinamičke elemente
- Alt-text za sve slike koje nose značenje
- Čitljiv font (minimum 16px za body tekst)
- Responzivan na sve veličine ekrana

### 5. Review checklist
Pre finalizacije, proveri:
- [ ] Svi CTA jasno komuniciraju šta će se desiti
- [ ] Cene su potpuno transparentne
- [ ] Otkazivanje/odjava je jednako laka kao i prijava
- [ ] Nema confirmshaming-a, lažne hitnosti ili lažne oskudice
- [ ] Cookie/privacy kontrole su fer
- [ ] Svi testimonijali su označeni kao realni
- [ ] Interfejs je pristupačan (kontrast, keyboard, screen reader)
- [ ] Default podešavanja favorizuju korisnika, ne kompaniju
- [ ] Microcopy je jasan, human-readable i bez manipulacije

## Tech Stack kontekst

Ovaj skill je optimizovan za Next.js (App Router) + Supabase + TypeScript + Tailwind stack, ali principi važe za bilo koji framework.

### Specifični paterni za Next.js/Supabase:

**Cookie consent:**
```tsx
// Koristi server-side consent checking
// Ne postavljaj tracking cookie-je dok korisnik eksplicitno ne pristane
// Čuvaj consent status u Supabase za transparentnost
```

**Subscription management sa Supabase:**
```tsx
// Otkazivanje pretplate: jednostavan API endpoint
// Jasan UI u dashboard-u korisnika
// Email potvrda sa datumom isteka i opcijom reactivation
```

**Pricing komponenta:**
```tsx
// Svi planovi prikazani ravnopravno
// Nema vizuelnog "guranja" ka skupljoj opciji
// Feature comparison tabela sa jasnim ✓/✗ bez skrivenih fussnota
```

## Akademska osnova

Ovaj skill je zasnovan na istraživanjima iz:
- REFLECT Framework (2025) — etički UX okvir
- Jon Yablonski: Humane by Design (2020) — 6 principa humanog dizajna
- Sánchez Chamorro et al. (2023, ACM DIS) — granica persuazije i manipulacije
- Schilling & Sergeeva (2026, SSRN) — podložnost dark patterns-ima
- EU Digital Services Act, Art. 25 — zabrana manipulativnog dizajna
