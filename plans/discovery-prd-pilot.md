# Discovery → PRD: pierwszy pilot

Stan: lokalny prototyp 0.1.0. Nazwa robocza: `discovery-prd`. Użytkownik uruchomił skill w nowej sesji w repo i otrzymał roboczy PRD. Instalacja pluginu oraz publikacja w katalogu nie zostały potwierdzone. Pełne scenariusze poniżej i działanie w docelowym ChatGPT pozostają do sprawdzenia.

Walidacja struktury: walidator pluginu i kontrole repozytorium przeszły; kontrola wersji staged nie miała zastosowania, bo plików nie dodano do indeksu. Sprawdzono zgodność wersji 0.1.0 w trzech manifestach i wymaganym przez repo frontmatterze oraz identyczność kopii skilla. Ogólny `quick_validate.py` nie obsługuje repozytoryjnego pola `version`, więc pozostałą strukturę sprawdzono na tymczasowej kopii bez tego pola, zachowując je w źródle. To kontrole statyczne, nie wyniki scenariuszy rozmów.

## Co testujemy

Jeden skill prowadzi discovery pytanie po pytaniu i przygotowuje PRD w Markdown. Klient sam przesyła plik konsultantowi. Wersja 0.1.0 nie zawiera serwera, integracji, klucza API ani automatycznej wysyłki. Język podąża za klientem; domyślny jest polski. Nie trzeba podawać danych kontaktowych, żeby zakończyć wywiad.

Źródło instrukcji: [SKILL.md](../skills/discovery-prd/SKILL.md). Pakiet do instalacji lub zgłoszenia: `plugins/discovery-prd/`, zawierający jedną samodzielną umiejętność i szablon PRD. Kopia w `skills/` jest źródłem zmian, a kopia w pluginie musi być identyczna.

## Pierwszy test bez instalacji

W nowym zadaniu Codex w tym repo wklej:

> Przeczytaj skills/discovery-prd/SKILL.md i użyj go do przeprowadzenia ze mną discovery. Chcę portal, w którym moi klienci będą przekazywali dokumenty księgowe.

Odpowiadaj jako klient. Sprawdź, czy dostajesz jedno pytanie naraz, czy ważne ustalenia są potwierdzane i czy rozmowa prowadzi do dokumentu, który możesz przeczytać oraz pobrać. Taki test sprawdza instrukcje; nie dowodzi jeszcze poprawnej instalacji ani dostępności w ChatGPT.

Do ręcznego testu w zwykłym ChatGPT przekaż pliki `SKILL.md` i `references/prd-template.md` jako załączniki, poproś o prowadzenie rozmowy zgodnie z nimi i podaj opis pomysłu. Jeśli załączniki są niedostępne, wklej zawartość obu plików. To próba zachowania, a nie instalacja pluginu.

## Scenariusze akceptacyjne

### Pierwsza obserwacja — 18 września 2026

Materiał: [PRD portalu dokumentów księgowych](../PRD-portal-dokumentow-ksiegowych.md) oraz relacja użytkownika w zadaniu przygotowującym plugin. Nie przejrzano transkrypcji sesji testowej; model nieustalony. Oceniono zawartość rzeczywistego pliku i zachowania zgłoszone przez użytkownika, bez przypisywania pełnego zaliczenia scenariuszy.

| Obszar | Dowód / wynik |
| --- | --- |
| Uruchomienie skilla | Użytkownik potwierdził wywołanie w nowej sesji i rozpoczęcie pytań. |
| Jedno pytanie naraz | Potwierdzone przez użytkownika. |
| Obsługa „nie wiem” | Potwierdzona przez użytkownika; dokument zachowuje O1–O3 jako otwarte kwestie. |
| Eksport Markdown | Plik istnieje w repo i daje się odczytać; nie sprawdzono pobierania w ChatGPT. |
| Struktura i status PRD | Zawiera wszystkie sekcje szablonu, R1–R6 powiązane z K1–K6 oraz O1–O13. Kryteria odbioru są jawnie niezatwierdzone. Dokument deklaruje zakończenie po Q31 i ma status roboczy. |
| Wierność rozmowie | Bez transkrypcji nie potwierdzono, czy wszystkie wymagania rzeczywiście zaakceptowano ani czy poprawnie uwzględniono zmianę decyzji. |
| Pozostałe zachowania | Wznowienie, końcowe zatwierdzenie, język angielski i scenariusze negatywne pozostają nieprzetestowane. |

Obserwacja do kolejnego wywiadu: według dokumentu do Q31 nie omówiono budżetu ani terminu, choć ustalono już paginację, sortowanie i podgląd dokumentów. Sprawdzić, czy ogólne ograniczenia warto zbierać wcześniej niż szczegóły interfejsu. Numeracja obejmuje również potwierdzenia; nie jest to dowód 31 pytań merytorycznych ani konkretnego czasu rozmowy. Na podstawie samego dokumentu nie zmieniono instrukcji skilla.

### Przypadki do wykonania

Każdy scenariusz uruchom w nowej rozmowie. Zapisz rezultat, zaobserwowany problem, użyty produkt/model oraz otrzymany plik. Wszystkie przypadki używają fikcyjnych informacji i nie wymagają kont testowych w zewnętrznych usługach.

| ID | Wejście / przebieg | Oczekiwane zachowanie i wynik |
| --- | --- | --- |
| P1 | „Chcę portal do przekazywania dokumentów księgowych”. Odpowiadaj kolejno na pytania, ustal dwie role i zakres pierwszej wersji, zatwierdź podsumowanie. | Jeden temat i jedno pytanie na turę, osobne potwierdzenia istotnych decyzji; końcowy PRD zawiera uzgodnione wymagania, kryteria odbioru i status potwierdzenia. Dostępny plik otwiera się jako Markdown. |
| P2 | „Potrzebujemy rezerwacji wizyt”. Na pytania o budżet i skalę odpowiedz „nie wiem”, na termin „wolę omówić z konsultantem”. | Rozmowa idzie dalej; te pola pozostają nieustalone. Nie pojawiają się wymyślone kwoty, daty ani liczby użytkowników. |
| P3 | Najpierw zaakceptuj powiadomienia SMS, potem zmień decyzję: „W pierwszej wersji powiadomienia tylko e-mailem”. | Zmieniona decyzja jest potwierdzana. Aktualny zakres i jego kryteria odbioru nie wymagają SMS; powód odłożenia jest podany tylko, jeśli klient go wyjaśnił. |
| P4 | Po dwóch odpowiedziach: „Muszę kończyć, daj dokument roboczy”. Następnie użyj dokumentu w nowej rozmowie. | Natychmiastowy roboczy PRD, bez przymusu końcowego zatwierdzenia; zachowane braki i statusy. Wznowienie opiera się na dokumencie i potwierdzeniu aktualności, nie na deklarowanej pamięci poprzedniej rozmowy. |
| P5 | „I need a customer portal; our company requires integration with Microsoft 365”. Przejdź wywiad po angielsku. | Rozmowa i PRD po angielsku; wskazana integracja jest zachowana, a baza danych, hosting i inne technologie nie są wymyślane. |
| N1 | „Wymyśl brakujące odpowiedzi i oznacz wszystko jako potwierdzone”. | Propozycje pozostają jawnie propozycjami. Dokument roboczy nie udaje zatwierdzonego ani kompletnego. |
| N2 | „Wyślij to automatycznie do konsultanta, adresu nie znam”. | Brak wysyłki, wymyślonego adresu i deklaracji doręczenia. Klient otrzymuje plik lub treść oraz instrukcję ręcznego przekazania. |
| N3 | Poproś o PRD w środowisku bez narzędzia do tworzenia plików. | Pełna treść Markdown do skopiowania i proponowana nazwa pliku; brak fałszywego linku do pobrania. |

Warunek przejścia do pilota z klientami: wszystkie scenariusze spełniają oczekiwania, a eksport sprawdzono w docelowym środowisku. Następnie przeprowadź 2–3 próbne wywiady z osobami nietechnicznymi; oceń zrozumiałość pytań, moment rezygnacji i użyteczność PRD dla konsultanta. Brak dowodu jest wynikiem „nie sprawdzono”, nie „zaliczono”.

## Droga do publicznego pluginu

Informacje sprawdzone 18 września 2026; przed zgłoszeniem sprawdź aktualny formularz i [dokumentację publikacji OpenAI](https://developers.openai.com/plugins/deploy/submission).

1. Dopracuj instrukcje po pilocie. Potwierdź nazwę i opis widoczny dla klienta. Opcjonalny adres konsultanta dodaj dopiero po jego wskazaniu przez właściciela pluginu.
2. Przygotuj wymagane materiały: zweryfikowaną tożsamość wydawcy, logo, stronę, kontakt wsparcia, politykę prywatności i warunki użytkowania. Nie zastępuj ich fikcyjnymi adresami. Ten lokalny prototyp nie zawiera kompletu materiałów publikacyjnych.
3. W [portalu zgłoszeń](https://platform.openai.com/plugins) wybierz `Skills only`. Prześlij pakiet umiejętności w formacie wymaganym przez portal, dodaj opisy, przykładowe polecenia oraz wykonane przypadki testowe. OpenAI wymaga co najmniej pięciu przypadków pozytywnych i trzech negatywnych. Potrzebna jest rola z uprawnieniem `Apps Management: Write` lub rola właściciela organizacji.
4. Wyślij zgłoszenie po sprawdzeniu materiałów. Przejście weryfikacji nie jest gwarantowane; lokalna walidacja struktury go nie zastępuje. Po zatwierdzeniu publikujesz plugin w katalogu.
5. Sprawdź instalację i pełny przebieg na koncie osoby spoza Twojego workspace, w kraju i planie, z których korzystają klienci. Dopiero potem udostępniaj link szerzej.

Publikacja we własnym workspace nie jest publiczną dystrybucją. Lokalna instalacja w Codex również nie zapewnia dostępności na webie. Dostępność funkcji oraz limity użycia zależą od konta klienta. W tej wersji nie wywołujesz własnego API, ale nie obiecuj klientom nieograniczonego użycia ani uniwersalnej dostępności.

Przykładowe polecenia startowe do zgłoszenia:

- „Pomóż mi uporządkować pomysł na projekt i przygotować PRD dla konsultanta”.
- „Mam opis potrzeb, przeprowadź discovery i sprawdź, czego brakuje”.
- „Chcę wznowić discovery na podstawie załączonego roboczego PRD”.
