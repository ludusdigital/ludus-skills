# ludus-skills

Kolekcija agent skillova za Ludus Digital. Svaki poddirektorijum je zaseban skill sa svojim `SKILL.md` fajlom i pratećim referencama. Svi skillovi su javno dostupni na [skills.sh](https://skills.sh/) i instaliraju se jednom komandom.

## Instalacija

Za instalaciju pojedinačnog skilla pokreni:

```bash
npx skills add https://github.com/ludusdigital/ludus-skills --skill carousel-aida-writer
npx skills add https://github.com/ludusdigital/ludus-skills --skill design-sprint
npx skills add https://github.com/ludusdigital/ludus-skills --skill ethical-design
npx skills add https://github.com/ludusdigital/ludus-skills --skill pojednostavljac
npx skills add https://github.com/ludusdigital/ludus-skills --skill universal-seo-aeo-blog-writer
npx skills add https://github.com/ludusdigital/ludus-skills --skill upc-integration
```

Kraći oblik iste komande: `npx skills add ludusdigital/ludus-skills@<ime-skilla>`.

Za globalnu instalaciju (dostupno svim agentima, bez interaktivnih pitanja) dodaj `-g -y`:

```bash
npx skills add https://github.com/ludusdigital/ludus-skills --skill carousel-aida-writer -g -y
```

## Skillovi

| Skill | Opis | Stranica |
| --- | --- | --- |
| [carousel-aida-writer](./carousel-aida-writer/SKILL.md) | Pisanje kompletnih Instagram carousel postova po AIDA principu (Attention, Interest, Desire, Action), spremnih za dizajn. | [skills.sh](https://skills.sh/ludusdigital/ludus-skills/carousel-aida-writer) |
| [design-sprint](./design-sprint/SKILL.md) | Vođenje kroz strukturisan Design Sprint proces prilagođen AI-native načinu rada: od definisanja problema do testiranja prototipa. | [skills.sh](https://skills.sh/ludusdigital/ludus-skills/design-sprint) |
| [ethical-design](./ethical-design/SKILL.md) | Etički principi dizajna i komunikacije za UI koji gradi poverenje i izbegava manipulativne obrasce (dark patterns). | [skills.sh](https://skills.sh/ludusdigital/ludus-skills/ethical-design) |
| [pojednostavljac](./pojednostavljac/SKILL.md) | Pretvara tehnička objašnjenja u jasne, bezbedne i proverljive instrukcije za početnike po PTS-VK standardu. | [skills.sh](https://skills.sh/ludusdigital/ludus-skills/pojednostavljac) |
| [universal-seo-aeo-blog-writer](./universal-seo-aeo-blog-writer/SKILL.md) | Pisanje blog postova koji istovremeno rangiraju na Google-u (SEO) i bivaju citirani od AI sistema (AEO/GEO). | [skills.sh](https://skills.sh/ludusdigital/ludus-skills/universal-seo-aeo-blog-writer) |
| [upc-integration](./upc-integration/SKILL.md) | Kompletna integracija UPC (Raiffeisen) payment gateway-a u Next.js + Supabase aplikaciju: RSA potpis, MIT transakcije, webhook-ovi. | [skills.sh](https://skills.sh/ludusdigital/ludus-skills/upc-integration) |

## Struktura skillova

Svaki skill prati standardnu strukturu:

- `SKILL.md` - glavni fajl sa uputstvima i opisom okidača
- `references/` - prateći referentni materijali
- dodatni direktorijumi po potrebi (`templates`, `phases`, `checklists`, `prompts`, `examples`)

## Korišćenje

Skillovi su namenjeni za učitavanje u agent okruženja (Claude Code, Cursor, DSH i slično) koja podržavaju skill format. Nakon instalacije, agent ih automatski učitava kada zadatak odgovara opisu skillova.
