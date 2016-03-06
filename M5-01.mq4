/*
****************************************************************************************************************************************************************************************
*                                                                                                                                                                                      *
* M5.mq4, verzija: 2, marec 2016                                                                                                                                                      *
*                                                                                                                                                                                      *
* Copyright Peter Novak ml., M.Sc.                                                                                                                                                     *
****************************************************************************************************************************************************************************************
*/

#property copyright "Peter Novak ml., M.Sc."
#property link      "http://www.marlin.si"



// Vhodni parametri --------------------------------------------------------------------------------------------------------------------------------------------------------------------
extern double d;                     // Razdalja med osnovnima ravnema za nakup in prodajo;
extern double r;                     // Razdalja med dodatnimi ravnmi za prodajo ali nakup;
extern double cz;                    // Začetna cena. Če je podana vrednost enaka 0, potem se algoritem zažene takoj in začetna cena postane trenutna cena valutnega para (Bid);
extern double L;                     // Velikost pozicij v lotih;
extern double p;                     // Profitni cilj;
extern int    samodejniPonovniZagon; // Samodejni ponovni zagon - DA(>0) ali NE(0). Če je po doseženem profitnem cilju ponovno dosežena začetna cena cz, se algoritem znova požene.
extern int    n;                     // Številka iteracije. Če želimo zagon nove iteracije, potem podamo vrednost 0;
extern double odmikSL;               // Odmik pri postavljanju stop-loss na break-even. Vrednost odmika prištejemo (buy) ali odštejemo (sell) ceni odprtja;



// Globalne konstante ------------------------------------------------------------------------------------------------------------------------------------------------------------------
#define MAX_POZ     99  // največje možno število odprtih pozicij v eno smer;
#define PROSTO     -1   // oznaka za vsebino polja bpozicije / spozicije;
#define ZASEDENO   -2   // oznaka za vsebino polja bpozicije / spozicije;
#define NEVELJAVNO -3   // oznaka za vrednost spremenljivk braven / sraven;
#define USPEH      -4   // oznaka za povratno vrednost pri uspešno izvedenem klicu funkcije;
#define NAPAKA     -5   // oznaka za povratno vrednost pri neuspešno izvedenem klicu funkcije;
#define S0          1   // oznaka za stanje S0 - Čakanje na zagon;
#define S1          2   // oznaka za stanje S1 - Začetno stanje;
#define S2          3   // oznaka za stanje S2 - Nakup;
#define S3          4   // oznaka za stanje S3 - Prodaja;
#define S4          5   // oznaka za stanje S4 - Zaključek;



// Globalne spremenljivke --------------------------------------------------------------------------------------------------------------------------------------------------------------
int    bpozicije [MAX_POZ]; // Enolične oznake vseh odprtih nakupnih pozicij;
int    braven;              // Trenutna raven na nakupni strani. Če je cena trenutno na prodajni strani, potem ima spremenljivka vrednost NEVELJAVNO;
double cenaObZagonu;        // hrani ceno ob trenutku zagona algoritma;
double ceneBravni[MAX_POZ]; // Cene posameznih nakupnih ravni;
double ceneSravni[MAX_POZ]; // Cene posameznih prodajnih ravni;
double ck;                  // Cena ob kateri je bil dosežen profitni cilj. Uporabljam jo za ugotavljanje ali je ponovno dosežena začetna cena cz (če je samodejniPonovniZagon DA)
double izkupicekIteracije;  // Izkupiček trenutne iteracije algoritma (izkupiček zaprtih pozicij);
double maxIzpostavljenost;  // Največja izguba algoritma (minimum od izkupickaIteracije);
double skupniIzkupicek;     // Hrani trenutni skupni izkupiček trenutne iteracije, vključno z vrednostjo trenutno odprtih pozicij
int    spozicije [MAX_POZ]; // Enolične oznake vseh odprtih prodajnih pozicij;
int    sraven;              // Trenutna raven na prodajni strani. Če je cena trenutno na nakupni strani, potem ima spremenljivka vrednost NEVELJAVNO.
int    stanje;              // Trenutno stanje algoritma;
int    stevilkaIteracije;   // Številka trenutne iteracije;
int    verzija = 2;         // Trenutna verzija algoritma;



/*
****************************************************************************************************************************************************************************************
*                                                                                                                                                                                      *
* GLAVNI PROGRAM in obvezne funkcije: init, deinit, start                                                                                                                              *
*                                                                                                                                                                                      *
****************************************************************************************************************************************************************************************
*/



/*--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
FUNKCIJA: deinit  
----------------
(o) Funkcionalnost: Sistem jo pokliče ob zaustavitvi. M5 je ne uporablja
(o) Zaloga vrednosti: USPEH (vedno uspe)
(o) Vhodni parametri: /
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/   
int deinit()
{
  return( USPEH );
} // deinit 



/*--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
FUNKCIJA: init  
--------------
(o) Funkcionalnost: Sistem jo pokliče ob zagonu. V njej izvedemo naslednje:
  (-) izpišemo pozdravno sporočilo
  (-) pokličemo funkcije, ki ponastavijo vse ključne podatkovne strukture algoritma na začetne vrednosti
  (-) začnemo novo iteracijo algoritma, če je podana številka iteracije 0 ali vzpostavimo stanje algoritma glede na podano številko iteracije 
(o) Zaloga vrednosti: USPEH, NAPAKA
(o) Vhodni parametri: /
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
int init()
{
  bool rezultat; // spremenljivka, ki hrani povratno informacijo ali je prišlo do napake pri branju podatkov iz datoteke
    
  IzpisiPozdravnoSporocilo();
  
  // ------------------ Blok za klice servisnih funkcij - na koncu odkomentiraj vrstico, ki pošlje algoritem v stanje S4.---------------------
  // ---sem vstavi klice servisnih funkcij - primer:
  // PrepisiZapisIteracije( 11200, 0.00100, 0.00100, 1.08772, 0.09, 0.00100, 0, 0.00010, "M5-11200-kopija-2.dat" );
  // PrepisiZapisIteracije( 11100, 0.00100, 0.00100, 1.08926, 0.08, 0.00100, 0, 0.00010, "M5-11100-kopija-2.dat" );
  // stanje = S4; samodejniPonovniZagon = 0; return( USPEH );
  // ------------------ Konec bloka za klice servisnih funkcij -------------------------------------------------------------------------------
  
  maxIzpostavljenost = 0;
  cenaObZagonu       = Bid;
  if( n == 0 ) // Številka iteracije ni podana - začnemo novo iteracijo
  { 
    PonastaviVrednostiPodatkovnihStruktur();
    stevilkaIteracije = OdpriNovoIteracijo();
    if( stevilkaIteracije == NAPAKA ) 
      { Print( "M5-V", verzija, ":init:USODNA NAPAKA: pridobivanje številke iteracije ni uspelo. Delovanje ustavljeno." ); stanje = S4; samodejniPonovniZagon = 0; return( NAPAKA ); }
      else                           
      { 
        Print( "M5-V", verzija, ":init:Odprta nova iteracija št. ", stevilkaIteracije ); n = stevilkaIteracije; 
        if( cz == 0 ) { ShraniIteracijo( stevilkaIteracije, cenaObZagonu ); } else { ShraniIteracijo( stevilkaIteracije, cz ); }
        stanje = S0; return( USPEH ); 
      }
  }
  else         // Številka iteracije je podana - nadaljujemo z obstoječo iteracijo
  {
    stevilkaIteracije = n;
    rezultat          = PreberiIteracijo( stevilkaIteracije ); 
    if( rezultat == NAPAKA ) { Print( "M5-V", verzija, ":init:USODNA NAPAKA: branje iteracije ni uspelo. Delovanje ustavljeno." ); stanje = S4; return( NAPAKA ); }
    stanje            = IzracunajStanje(); 
    if( stanje   != NAPAKA ) { return( USPEH ); }
    else                     { Print( "M5-V", verzija, ":init:USODNA NAPAKA: izračun stanja algoritma ni uspel. Delovanje ustavljeno." ); stanje = S4; return( NAPAKA ); }                                                                                                       
  }
  Print( "M5-V", verzija, ":init:OPOZORILO: ta stavek se ne bi smel izvršiti - preveri pravilnost delovanja algoritma" );
  return( USPEH );
} // init



/*--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
FUNKCIJA: start  
---------------
(o) Funkcionalnost: Glavna funkcija, ki upravlja celoten algoritem - sistem jo pokliče ob vsakem ticku. 
(o) Zaloga vrednosti: USPEH (funkcija vedno uspe)
(o) Vhodni parametri: /
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
int start()
{
  int trenutnoStanje; // zabeležimo za ugotavljanje spremebe stanja
 
  trenutnoStanje = stanje;
  switch( stanje )
  {
    case S0: stanje = S0CakanjeNaZagon(); break;
    case S1: stanje = S1ZacetnoStanje();  break;
    case S2: stanje = S2Nakup();          break;
    case S3: stanje = S3Prodaja();        break;
    case S4: stanje = S4Zakljucek();      break;
    default: Print( "M5-V", verzija, ":[", stevilkaIteracije, "]:", ":start:OPOZORILO: Stanje ", stanje, " ni veljavno stanje - preveri pravilnost delovanja algoritma." );
  }
  // če je prišlo do prehoda med stanji izpišemo obvestilo
  if( trenutnoStanje != stanje ) { Print( ":[", stevilkaIteracije, "]:", "Prehod: ", ImeStanja( trenutnoStanje ), " ===========>>>>> ", ImeStanja( stanje ) ); }

  // če se je poslabšala izpostavljenost, to zabeležimo
  if( maxIzpostavljenost > skupniIzkupicek ) { maxIzpostavljenost = skupniIzkupicek; Print( ":[", stevilkaIteracije, "]:", "Nova največja izpostavljenost: ", DoubleToString( maxIzpostavljenost, 5 ) ); }
    
  // osveževanje ključnih kazalnikov delovanja algoritma na zaslonu
  Comment( "Številka iteracije: ",       stevilkaIteracije,                        " \n",  
           "Začetna cena:",              DoubleToString( cz,                  5 ), " \n",
           "Izkupiček iteracije: ",      DoubleToString( izkupicekIteracije,  5 ), " \n",
           "Skupni izkupiček:",          DoubleToString( skupniIzkupicek,     5 ), " \n",
           "Razdalja do cilja: ",        DoubleToString( p - skupniIzkupicek, 5 ), " \n",
           "Največja izpostavljenost: ", DoubleToString( maxIzpostavljenost,  5 ) );
  
  return( USPEH );
} // start



/*
****************************************************************************************************************************************************************************************
*                                                                                                                                                                                      *
* POMOŽNE FUNKCIJE                                                                                                                                                                     *
* Urejene po abecednem vrstnem redu                                                                                                                                                    *
****************************************************************************************************************************************************************************************
*/



/*--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
FUNKCIJA: ImeStanja( int KodaStanja )
-------------------------------------
(o) Funkcionalnost: Na podlagi numerične kode stanja, vrne opis stanja.  
(o) Zaloga vrednosti: imena stanj
(o) Vhodni parametri: KodaStanja: enolična oznaka stanja. 
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
string ImeStanja( int KodaStanja )
{
  switch( KodaStanja )
  {
    case S0: return( "S0 - ČAKANJE NA ZAGON" );
    case S1: return( "S1 - ZAČETNO STANJE"   );
    case S2: return( "S2 - NAKUP"            );
    case S3: return( "S3 - PRODAJA"          );
    case S4: return( "S4 - ZAKLJUČEK"        );
    default: Print ( "M5-V", verzija, ":[", stevilkaIteracije, "]:", ":ImeStanja:OPOZORILO: Koda stanja ", KodaStanja, " ni prepoznana. Preveri pravilnost delovanja algoritma." );
  }
  return( NAPAKA );
} // ImeStanja



/*--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
FUNKCIJA: IzkupicekZaprtihPozicijIteracije( st )
-----------------------------------------------
(o) Funkcionalnost: pregleda vse zaprte pozicije in sešteje izkupiček (v točkah) tistih pozicij, ki pripadajo iteraciji st
(o) Zaloga vrednosti: izkupiček zaprtih pozicij. Če ni nobene zaprte pozicije, potem vrne vrednost 0.
(o) Vhodni parametri: številka iteracije
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
double IzkupicekZaprtihPozicijIteracije( int st )
{
  int    magicNumberN; // hramba za magic number ukaza, ki ga trenutno obdelujemo
  int    stIteracijeI; // hramba za stevilko iteracije ukaza, ki ga trenutno obdelujemo
  int    ravenK;       // hramba za raven ukaza, ki ga trenutno obdelujemo
  double izkupicek;    // hramba trenutne vrednosti izkupička
  int    stUkazov;     // stevilo ukazov v zgodovini terminala

  stUkazov  = OrdersHistoryTotal();
  izkupicek = 0;
  for( int i = 0; i < stUkazov; i++ )
  {
    if( OrderSelect( i, SELECT_BY_POS, MODE_HISTORY ) == false ) 
    { Print( "M5-V", verzija, ":[", stevilkaIteracije, "]:", ":IzkupicekZaprtihPozicijIteracije: Napaka pri dostopu do zgodovine pozicij." ); return( 0 ); } 
    else                   
    {
      magicNumberN = OrderMagicNumber();
      ravenK       = magicNumberN % 100;
      stIteracijeI = magicNumberN - ravenK;
      if( stIteracijeI == st ) { izkupicek = izkupicek + VrednostPozicije( OrderTicket() ); }
    }
  }
  return( izkupicek );
} // IzkupicekZaprtihPozicijIteracije



/*--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
FUNKCIJA: IzpisiPozdravnoSporocilo
----------------------------------
(o) Funkcionalnost: izpiše pozdravno sporočilo, ki vsebuje tudi verzijo algoritma
(o) Zaloga vrednosti: USPEH (funkcija vedno uspe)
(o) Vhodni parametri: /
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
int IzpisiPozdravnoSporocilo()
{
  Print( "****************************************************************************************************************" );
  Print( "Dober dan. Tukaj M5, verzija ", verzija, "." );
  Print( "****************************************************************************************************************" );
  return( USPEH );
} // IzpisiPozdravnoSporocilo



/*--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
FUNKCIJA: IzpolnjenPogojZaPonovniZagon
--------------------------------------
(o) Funkcionalnost: izračuna ali je trenutna cena valutnega para ponovno dosegla začetno ceno. Uporablja se v kombinaciji z nastavitvijo za samodejni ponovni zagon algoritma, potem ko
    je enkrat že doseženo končno stanje
(o) Zaloga vrednosti: 
  (-) true: cena je ponovno dosegla začetno ceno;
  (-) false: cena ni ponovno dosegla začetne cena.
(o) Vhodni parametri: /
  (-) uporablja globalni spremenljivki cz in ck
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
bool IzpolnjenPogojZaPonovniZagon()
{
  if( ck > cz) { if( Bid <= cz ) { return( true ); } else { return( false ); } }
  else         { if( Bid >= cz ) { return( true ); } else { return( false ); } }
  Print( "M5-V", verzija, ":[", stevilkaIteracije, "]:", ":IzpolnjenPogojZaPonovniZagon:OPOZORILO: Ta stavek se ne bi smel nikoli izvesti - preveri delovanje algoritma." );
} // IzpolnjenPogojZaPonovniZagon



/*--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
FUNKCIJA: IzracunajStanje
-------------------------
(o) Funkcionalnost: glede na trenutno stanje podatkovnih struktur algoritma in trenutno ceno valutnega para (Bid) izračuna stanje algoritma
(o) Zaloga vrednosti: 
 (-) če je bilo stanje algoritma mogoče izračunati, potem vrne kodo stanja
 (-) NAPAKA: stanja ni bilo mogoče izračunati
(o) Vhodni parametri: / - uporablja globalne podatkovne strukture
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
int IzracunajStanje()
{
  int i; // stevec
  
  i = 0;
  if( Bid >= ceneBravni[ 0 ] ) 
  { 
    sraven = NEVELJAVNO; while( ( ceneBravni[ i+1 ] <= Bid ) && ( i < MAX_POZ-1 ) ) { i++; }
    if( ceneBravni[ i+1 ] > Bid ) { braven = i; Print( ":[", stevilkaIteracije, "]:", "Stanje algoritma: ", ImeStanja( S2 ), ". Trenutna raven je: ", braven ); return( S2 ); }
    else                          { return( NAPAKA ); }
  }
  if( Bid <= ceneSravni[ 0 ] ) 
  { 
    braven = NEVELJAVNO; while( ( ceneSravni[ i+1 ] >= Bid ) && ( i < MAX_POZ-1 ) ) { i++; }
    if( ceneSravni[ i+1 ] < Bid ) { sraven = i; Print( ":[", stevilkaIteracije, "]:", "Stanje algoritma: ", ImeStanja( S3 ), ". Trenutna raven je: ", sraven ); return( S3 ); }
    else                          { return( NAPAKA ); }
  }
  if( ( Bid < ceneBravni[ 0 ] ) && ( Bid > ceneSravni[ 0 ] ) ) 
  {
    if( ObstajaOdprtaPozicija( OP_BUY  ) == true ) { sraven = NEVELJAVNO; braven = 0; Print( ":[", stevilkaIteracije, "]:", "Stanje algoritma: ", ImeStanja( S2 ), ". Trenutna raven je: 0" ); return( S2 ); }
    if( ObstajaOdprtaPozicija( OP_SELL ) == true ) { braven = NEVELJAVNO; sraven = 0; Print( ":[", stevilkaIteracije, "]:", "Stanje algoritma: ", ImeStanja( S3 ), ". Trenutna raven je: 0" ); return( S3 ); }
    // če ne obstaja ne odprta nakupna in ne odprta prodajna pozicija, potem gremo v začetno stanje
    sraven = NEVELJAVNO; braven = NEVELJAVNO; Print( ":[", stevilkaIteracije, "]:", "Stanje algoritma: ", ImeStanja( S1 ) ); return( S1 );
  }
  Print( "M5-V", verzija, ":[", stevilkaIteracije, "]:", ":IzracunajStanje:OPOZORILO: Ta stavek se nikoli ne bi smel izvesti - preveri pravilnost delovanja algoritma." );
  return( NAPAKA );
} // IzracunajStanje



/*--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
FUNKCIJA: ObstajaOdprtaPozicija( vrsta )
----------------------------------------
(o) Funkcionalnost: preveri ali v polju bpozicije ali spozicije obstaja kakšen element, ki nima vrednosti PROSTO.
(o) Zaloga vrednosti:
 (-) true - če obstaja tak element
 (-) false - tak element ne obstaja ali je podana napačna vrsta pozicij.
(o) Vhodni parametri: 
 (-) OP_BUY - če iščemo v polju bpozicije
 (-) OP_SELL - če iščemo v polju spozicije
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
bool ObstajaOdprtaPozicija( int vrsta )
{
  int i; // števec
  
  i = 0;
  switch( vrsta )
  {
    case OP_BUY: 
      while( ( bpozicije[ i ] == PROSTO ) && ( i < MAX_POZ ) ) { i++; } 
      if( bpozicije[ i ] != PROSTO ) { return( true ); } else { return( false ); }
    case OP_SELL: 
      while( ( spozicije[ i ] == PROSTO ) && ( i < MAX_POZ ) ) { i++; } 
      if( spozicije[ i ] != PROSTO ) { return( true ); } else { return( false ); }
    default: 
      Print( "M5-V", verzija, ":[", stevilkaIteracije, "]:",  ":ObstajaOdprtaPozicija:OPOZORILO: Neznana vrsta pozicij." ); return( false ); 
  }
  Print( "M5-V", verzija, ":[", stevilkaIteracije, "]:", ":ObstajaOdprtaPozicija:OPOZORILO: Ta stavek se nikoli ne bi smel izvesti - preveri pravilnost delovanja algoritma." );
  return( false );
} // ObstajaOdprtaPozicija



/*--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
FUNKCIJA: OdpriNovoIteracijo
----------------------------
(o) Funkcionalnost: 
  (-) preveri ali globalna spremenljivka M5Iteracija obstaja
  (-) če obstaja, potem prebere njeno vrednost, jo poveča za 100, shrani nazaj in shranjeno vrednost vrne kot številko iteracije
  (-) če ne obstaja, potem jo ustvari, nastavi njeno vrednost na 100 in vrne 100 kot številko iteracije
(o) Zaloga vrednosti:
  (-) številka iteracije, če ni bilo napake
  (-) NAPAKA, če je pri branju ali pisanju v globalno spremenljivko prišlo do napake
(o) Vhodni parametri: /
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
int OdpriNovoIteracijo()
{
  double   i;        // hramba za trenutno vrednost iteracije
  datetime rezultat; // hramba za rezultat nastavljanja globalne spremenljivke M5Iteracija

  if( GlobalVariableCheck( "M5Iteracija" ) == true ) { i = GlobalVariableGet( "M5Iteracija" ); i = i + 100; } else { i = 100; }
  rezultat = GlobalVariableSet( "M5Iteracija", i );
  if( rezultat == 0 ) { Print( "M5-V", verzija, ":OdpriNovoIteracijo:NAPAKA: Pri shranjevanju številke iteracije ", i, " je prišlo do napake." ); return( NAPAKA ); }
  return( i );
} // OdpriNovoIteracijo



/*--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
FUNKCIJA: OdpriPozicijo( int Smer, double sl, int r )
----------------------------------------------------
(o) Funkcionalnost: Odpre pozicijo po trenutni tržni ceni v podani Smeri in nastavi stop loss na podano ceno
(o) Zaloga vrednosti: ID odprte pozicije;
(o) Vhodni parametri:
 (-) Smer: OP_BUY ali OP_SELL
 (-) sl: cena za stop loss
 (-) raven: raven na kateri odpiramo pozicijo
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
int OdpriPozicijo( int Smer, double sl, int raven )
{
  int rezultat;    // spremenljivka, ki hrani rezultat odpiranja pozicije
  int magicNumber; // spremenljivka, ki hrani magic number pozicije
  string komentar; // spremenljivka, ki hrani komentar za pozicijo
 
  magicNumber = stevilkaIteracije + raven;
  komentar    = StringConcatenate( "M5V", verzija, "-", stevilkaIteracije, "-", raven );

  do
    {
      if( Smer == OP_BUY ) { rezultat = OrderSend( Symbol(), OP_BUY,  L, Ask, 0, sl, 0, komentar, magicNumber, 0, Green ); }
      else                 { rezultat = OrderSend( Symbol(), OP_SELL, L, Bid, 0, sl, 0, komentar, magicNumber, 0, Red   ); }
      if( rezultat == -1 ) 
        { 
          Print( "M5-V", verzija, ":[", stevilkaIteracije, "]:", ":OdpriPozicijo:NAPAKA: neuspešno odpiranje pozicije. Ponoven poskus čez 30s..." ); 
          Sleep( 30000 );
          RefreshRates();
        }
    }
  while( rezultat == -1 );
  return( rezultat );
} // OdpriPozicijo



/*--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
FUNKCIJA: OsveziCeneRavni( c )
---------------------------
(o) Funkcionalnost: Nastavi cene ravni v poljih ceneBravni in ceneSravni, glede na podano začetno ceno
(o) Zaloga vrednosti: USPEH (vedno uspe)
(o) Vhodni parametri: začetna cena
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
int OsveziCeneRavni( double c )
{
  if( c == 0 ) { c = cenaObZagonu; }
  ceneBravni[ 0 ] = c + d/2; Print( ":[", stevilkaIteracije, "]:", "Nakupna raven 0: ",  DoubleToString( ceneBravni[ 0 ], 5 ) );
  ceneSravni[ 0 ] = c - d/2; Print( ":[", stevilkaIteracije, "]:", "Prodajna raven 0: ", DoubleToString( ceneSravni[ 0 ], 5 ) );
  for( int i = 1; i < MAX_POZ; i++ ) { ceneBravni[ i ] = ceneBravni[ i-1 ] + r; ceneSravni[ i ] = ceneSravni[ i-1 ] - r; }
  return( USPEH );
} // OsveziCeneRavni



/*--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
FUNKCIJA: PonastaviVrednostiPodatkovnihStruktur
-----------------------------------------------
(o) Funkcionalnost: Funkcija nastavi vrednosti vseh globalnih spremenljivk na začetne vrednosti.
 (-) napolni polje ceneBravni
 (-) napolni polje ceneSravni
 (-) nastavi vrednosti vseh elementov polja bpozicije na PROSTO
 (-) nastavi vrednosti vseh elementov polja spozicije na PROSTO
 (-) nastavi vrednost spremenljivke braven na NEVELJAVNO
 (-) nastavi vrednost spremenljivke sraven na NEVELJAVNO
 (-) nastavi vrednost spremenljivke izkupicekIteracije na 0
(o) Zaloga vrednosti: 
 (-) USPEH: ponastavljanje uspešno
 (-) NAPAKA: ponastavljanje ni bilo uspešno
(o) Vhodni parametri: uporablja globalne spremenljivke - parametre algoritma ob zagonu
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
int PonastaviVrednostiPodatkovnihStruktur()
{
  OsveziCeneRavni( cz );
  SprostiPozicije( OP_BUY  );
  SprostiPozicije( OP_SELL );
  braven = NEVELJAVNO;
  sraven = NEVELJAVNO;
  izkupicekIteracije = 0;
  skupniIzkupicek    = 0;
  ck                 = 0;
  return( USPEH );
} // PonastaviVrednostiPodatkovnihStruktur



/*--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
FUNKCIJA: PostaviSL( int id, double r )
---------------------------------------
(o) Funkcionalnost: Funkcija poziciji z id-jem id postavi stop loss r točk od vstopne cene:
 (-) če gre za nakupno pozicijo, potem se odmik r PRIŠTEJE k ceni odprtja. Ko je enkrat stop loss postavljen nad ceno odprtja, ga ni več mogoče postaviti pod ceno odprtja, tudi če 
     podamo negativen r
 (-) če gre za prodajno pozicijo, potem se odmik r ODŠTEJE od cene odprtja. Ko je enkrat stop loss postavljen pod ceno odprtja, ga ni več mogoče postaviti nad ceno odprtja, tudi če 
     podamo negativen r
(o) Zaloga vrednosti:
 (-) USPEH: ponastavljanje uspešno
 (-) NAPAKA: ponastavljanje ni bilo uspešno
(o) Vhodni parametri:
 (-) id: oznaka pozicije
 (-) odmik: odmik
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
int PostaviSL( int id, double odmik )
{
  double ciljniSL;
  bool   modifyRezultat;
  int    selectRezultat;
  string sporocilo;

  selectRezultat = OrderSelect( id, SELECT_BY_TICKET );
  if( selectRezultat == false ) 
  { 
    Print( "M5-V", verzija, ":[", stevilkaIteracije, "]:",  ":PostaviSL:NAPAKA: Pozicije ", id, " ni bilo mogoče najti. Preveri pravilnost delovanja algoritma." ); return( NAPAKA ); 
  }
  
  if( OrderType() == OP_BUY ) { if( OrderStopLoss() >= OrderOpenPrice() ) { return( USPEH ); } else { ciljniSL = OrderOpenPrice() + odmik; } } 
  else                        { if( OrderStopLoss() <= OrderOpenPrice() ) { return( USPEH ); } else { ciljniSL = OrderOpenPrice() - odmik; } }
  
  modifyRezultat = OrderModify( id, OrderOpenPrice(), ciljniSL, 0, 0, clrNONE );
  if( modifyRezultat == false ) 
  { 
    Print( "M5-V", verzija, ":[", stevilkaIteracije, "]:", ":PostaviSL:OPOZORILO: Pozicije ", id, " ni bilo mogoče ponastaviti SL. Preveri ali je že ponastavljeno. Koda napake: ", GetLastError() ); 
    Print( "M5-V", verzija, ":[", stevilkaIteracije, "]:", ":PostaviSL:Obstoječi SL = ", DoubleToString( OrderStopLoss(), 5 ), " Ciljni SL = ", DoubleToString( ciljniSL, 5 ) );
    sporocilo = "M5-V" + verzija + ":PostaviSL:Postavi SL pozicije " + id + " na " + DoubleToString( ciljniSL, 5 );
    SendNotification( sporocilo );
    return( NAPAKA ); 
  }           
  else 
  { 
    return( USPEH ); 
  }
} // PostaviSL



/*--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
FUNKCIJA: PozicijaZaprta( int id )
----------------------------------
(o) Funkcionalnost: Funkcija pove ali je pozicija s podanim id-jem zaprta ali ne. 
(o) Zaloga vrednosti:
 (-) true : pozicija je zaprta.
 (-) false: pozicija je odprta.
(o) Vhodni parametri: id - oznaka pozicije
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
bool PozicijaZaprta( int id )
{
  int Rezultat;

  Rezultat = OrderSelect( id, SELECT_BY_TICKET );
  if( Rezultat         == false ) { Print( "M5-V", verzija, ":[", stevilkaIteracije, "]:", ":PozicijaZaprta:OPOZORILO: Pozicije ", id, " ni bilo mogoče najti. Preveri pravilnost delovanja algoritma." ); return( true );}
  if( OrderCloseTime() == 0     ) { return( false ); } 
  else                            { return( true );  }
} // PozicijaZaprta



/*--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
FUNKCIJA: PreberiIteracijo( int stIteracije )
(o) Funkcionalnost:
 (-) prebere naslednje parametre algoritma iz datoteke M5-n.dat:
  (*) razdalja med osnovnima ravnema - d
  (*) razdalja med dodatnimi ravnmi za prodajo ali nakup - r
  (*) začetna cena - cz
  (*) velikost pozicij v lotih - L
  (*) profitni cilj - p
  (*) indikator samodejnega ponovnega zagona - samodejniPonovni Zagon
 (-) sešteje izkupiček vseh zaprtih pozicij, ki pripadajo iteraciji n in ga shrani v spremenljivko izkupiček iteracije
 (-) napolni polje ceneBravni
 (-) napolni polje ceneSravni
 (-) nastavi vrednost vseh elementov polja bpozicije na PROSTO
 (-) nastavi vrednost vseh elementov polja spozicije na PROSTO
 (-) pregleda odprte nakupne pozicije in tiste, ki pripadajo iteraciji n, prepiše na ustrezne ravni v polje bpozicije
 (-) pregleda odprte prodajne pozicije in tiste, ki pripadajo iteraciji n, prepiše na ustrezne ravni v polje spozicije
(o) Zaloga vrednosti: 
 (-) USPEH: če so bile vrednosti prebrane brez napak
 (-) NAPAKA: če je prišlo pri branju vrednosti do napake
(o) Vhodni parametri: številka iteracije, ostalo pridobimo iz globalnih spremenljivk
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
int PreberiIteracijo( int stIteracije )
{
  int    rocajDatoteke;
  string imeDatoteke;

  imeDatoteke = StringConcatenate( "M5-", stIteracije, ".dat" );
  ResetLastError();
  rocajDatoteke = FileOpen( imeDatoteke, FILE_READ|FILE_BIN );
  if( rocajDatoteke != INVALID_HANDLE)
  {
    d                     = FileReadDouble ( rocajDatoteke, DOUBLE_VALUE );
    r                     = FileReadDouble ( rocajDatoteke, DOUBLE_VALUE );
    cz                    = FileReadDouble ( rocajDatoteke, DOUBLE_VALUE );
    L                     = FileReadDouble ( rocajDatoteke, DOUBLE_VALUE );
    p                     = FileReadDouble ( rocajDatoteke, DOUBLE_VALUE );
    samodejniPonovniZagon = FileReadInteger( rocajDatoteke, INT_VALUE    );
    odmikSL               = FileReadDouble ( rocajDatoteke, DOUBLE_VALUE );
    Print( "Branje stanja iteracije iz datoteke ", imeDatoteke, ": -------------------------------------------------------------------------" );
    Print( "  Razdalja med osnovnima ravnema za nakup in prodajo [d]: ",         DoubleToString( d,       5 ) );
    Print( "  Razdalja med dodatnimi ravnmi za nakup in prodajo [r]: ",          DoubleToString( r,       5 ) );
    Print( "  Začetna cena [cz]: ",                                              DoubleToString( cz,      5 ) );
    Print( "  Velikost pozicij v lotih [L]: ",                                   DoubleToString( L,       5 ) );
    Print( "  Profitni cilj [p]: ",                                              DoubleToString( p,       5 ) );
    Print( "  Indikator samodejnega ponovnega zagona [samodejniPonovniZagon]: ", samodejniPonovniZagon        );
    Print( "  Odmik stop loss [odmikSL]: ",                                      DoubleToString( odmikSL, 5 ) );
    Print( "--------------------------------------------------------------------------------------------------------------------------------------------" );
    FileClose( rocajDatoteke );
  }
  else 
  { Print( "M5-V", verzija, ":PreberiIteracijo:USODNA NAPAKA: Odpiranje datoteke ", imeDatoteke, " ni bilo uspešno." ); return( NAPAKA ); }
  izkupicekIteracije = IzkupicekZaprtihPozicijIteracije( stIteracije ); Print( "  Izkupicek iteracije: ", DoubleToString( izkupicekIteracije, 5 ) );
  skupniIzkupicek    = izkupicekIteracije;
  OsveziCeneRavni( cz );
  SprostiPozicije( OP_BUY  );
  SprostiPozicije( OP_SELL );
  VpisiOdprtePozicije( stIteracije );
  return( USPEH );
} // PreberiIteracijo



/*--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
FUNKCIJA: ShraniIteracijo( stIteracije )
---------------------------
(o) Funkcionalnost: Funkcija shrani podatke o trenutni iteraciji n v datoteko:
 (-) zapiše naslednje parametre algoritma v datoteke M5-n.dat:
  (*) razdalja med osnovnima ravnema - d
  (*) razdalja med dodatnimi ravnmi za prodajo ali nakup - r
  (*) začetna cena - cz
  (*) velikost pozicij v lotih - L
  (*) profitni cilj - p
  (*) indikator samodejnega ponovnega zagona - samodejniPonovni Zagon
(o) Zaloga vrednosti:
 (-) USPEH  - odpiranje datoteke je bilo uspešno
 (-) NAPAKA - odpiranje datoteke ni bilo uspešno
(o) Vhodni parametri: eksplicitno sta podana spodnji dve vrednosti, ostale vrednosti se preberejo iz globalnih spremenljivk.
  (*) stIteracije - številka iteracije
  (*) cena - cena, ki jo shranimo kot začetno ceno iteracije
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
int ShraniIteracijo( int stIteracije, double cena )
{
  int    rocajDatoteke;
  string imeDatoteke;

  imeDatoteke = StringConcatenate( "M5-", stIteracije, ".dat" );
  rocajDatoteke = FileOpen( imeDatoteke, FILE_WRITE|FILE_BIN );
  if( rocajDatoteke != INVALID_HANDLE)
  {
    FileWriteDouble ( rocajDatoteke, d    );
    FileWriteDouble ( rocajDatoteke, r    );
    FileWriteDouble ( rocajDatoteke, cena );
    FileWriteDouble ( rocajDatoteke, L    );
    FileWriteDouble ( rocajDatoteke, p    );
    FileWriteInteger( rocajDatoteke, samodejniPonovniZagon );
    FileWriteDouble ( rocajDatoteke, odmikSL );
    Print( "Zapisovanje stanja iteracije ", stIteracije, " v datoteko ", imeDatoteke, ": -------------------------------------------------------------------------" );
    Print( "  Razdalja med osnovnima ravnema za nakup in prodajo [d]: ",         DoubleToString( d,       5 ) );
    Print( "  Razdalja med dodatnimi ravnmi za nakup in prodajo [r]: ",          DoubleToString( r,       5 ) );
    Print( "  Začetna cena [cz]: ",                                              DoubleToString( cena,    5 ) );
    Print( "  Velikost pozicij v lotih [L]: ",                                   DoubleToString( L,       5 ) );
    Print( "  Profitni cilj [p]: ",                                              DoubleToString( p,       5 ) );
    Print( "  Indikator samodejnega ponovnega zagona [samodejniPonovniZagon]: ", samodejniPonovniZagon        );
    Print( "  Odmik stop loss [odmikSL]: ",                                      DoubleToString( odmikSL, 5 ) );
    Print( "--------------------------------------------------------------------------------------------------------------------------------------------" );
    FileClose( rocajDatoteke );
  }
  else 
  { Print( "M5-V", verzija, ":ShraniIteracijo:USODNA NAPAKA: Odpiranje datoteke ", imeDatoteke, " ni bilo uspešno." ); return( NAPAKA ); }
  return( USPEH );
} // ShraniIteracijo



/*--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
FUNKCIJA: SprostiPozicije( vrsta )
----------------------------------
(o) Funkcionalnost: Nastavi vrednosti vseh elementov polja spozicije ali bpozicije na PROSTO.
(o) Zaloga vrednosti: USPEH (vedno uspe)
(o) Vhodni parametri: vrsta pozicij
 (-) če je podana vrednost OP_BUY, potem ponastavimo elemente polja bpozicije
 (-) če je podana vrednost OP_SELL, potem ponastavimo elemente polja spozicije
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
int SprostiPozicije( int vrsta )
{
  switch( vrsta )
  {
    case OP_BUY:  for( int i = 0; i < MAX_POZ; i++ ) { bpozicije[ i ] = PROSTO; } return( USPEH ); 
    case OP_SELL: for( int j = 0; j < MAX_POZ; j++ ) { spozicije[ j ] = PROSTO; } return( USPEH );
    default: Print( "M5-V", verzija, ":SprostiPozicije:OPOZORILO: Podana je bila neznana vrsta pozicij - preveri pravilnost delovanja algoritma." );
  }
  return( USPEH );
} // SprostiPozicije



/*--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
FUNKCIJA: VpisiOdprtePozicije( int st )
----------------------------------
(o) Funkcionalnost: pregleda vse trenutno odprte pozicije in prepiše tiste, ki pripadajo iteraciji st na ustrezno raven v tabelah bpozicije / spozicije
(o) Zaloga vrednosti: USPEH (vedno uspe)
(o) Vhodni parametri: st - številka iteracije
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
int VpisiOdprtePozicije( int st )
{
  int    magicNumberN; // hramba za magic number ukaza, ki ga trenutno obdelujemo
  int    stIteracijeI; // hramba za stevilko iteracije ukaza, ki ga trenutno obdelujemo
  int    ravenK;       // hramba za raven ukaza, ki ga trenutno obdelujemo
  int    stUkazov;     // stevilo odprtih pozicij v terminalu

  stUkazov  = OrdersTotal();
  for( int i = 0; i < stUkazov; i++ )
  {
    if( OrderSelect( i, SELECT_BY_POS ) == false ) 
    { Print( "M5-V", verzija, ":VpisiOdprtePozicije:OPOZORILO: Napaka pri dostopu do odprtih pozicij." ); } 
    else                   
    {
      magicNumberN = OrderMagicNumber();
      ravenK       = magicNumberN % 100;
      stIteracijeI = magicNumberN - ravenK;
      if( stIteracijeI == st ) 
      { 
        switch( OrderType() ) 
        {
          case OP_BUY:  bpozicije[ ravenK ] = OrderTicket(); Print(  "BUY pozicija ", OrderTicket(), ", iteracije ", stIteracijeI, " vpisana na raven ", ravenK ); break;
          case OP_SELL: spozicije[ ravenK ] = OrderTicket(); Print( "SELL pozicija ", OrderTicket(), ", iteracije ", stIteracijeI, " vpisana na raven ", ravenK ); break; 
          default: Print( "M5-V", verzija, ":VpisiOdprtePozicije:OPOZORILO: Nepričakovana vrsta ukaza." ); 
        }
      }
    } 
  } 
  return( USPEH );
} // VpisiOdprtePozicije



/*--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
FUNKCIJA: VrednostPozicije( int id )
------------------------------------
(o) Funkcionalnost: Vrne vrednost pozicije z oznako id v točkah
(o) Zaloga vrednosti: vrednost pozicije v točkah
(o) Vhodni parametri: id - oznaka pozicije
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
double VrednostPozicije( int id )
{
  bool rezultat;
  int  vrstaPozicije;
  
  rezultat = OrderSelect( id, SELECT_BY_TICKET );
  if( rezultat == false ) { Print( "M5-V", verzija, ":[", stevilkaIteracije, "]:", ":VrednostPozicije:NAPAKA: Pozicije ", id, " ni bilo mogoče najti. Preveri pravilnost delovanja algoritma." ); return( 0 ); }
  vrstaPozicije = OrderType();
  switch( vrstaPozicije )
  {
    case OP_BUY : if( OrderCloseTime() == 0 ) { return( Bid - OrderOpenPrice() ); } else { return( OrderClosePrice() - OrderOpenPrice()  ); }
    case OP_SELL: if( OrderCloseTime() == 0 ) { return( OrderOpenPrice() - Ask ); } else { return(  OrderOpenPrice() - OrderClosePrice() ); }
    default     : Print( "M5-V", verzija, ":[", stevilkaIteracije, "]:", ":VrednostPozicije:NAPAKA: Vrsta ukaza ni ne BUY ne SELL. Preveri pravilnost delovanja algoritma." ); return( 0 );
  }
} // VrednostPozicije



/*--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
FUNKCIJA: VrednostOdprtihPozicij()
-----------------------------------
(o) Funkcionalnost: Vrne vsoto vrednosti vseh odprtih pozicij, razen prve. Prve ne upoštevamo, ker jo bomo pustili za stonogo.
(o) Zaloga vrednosti: vsota vrednosti odprtih pozicij v točkah; 
(o) Vhodni parametri: / - uporablja globalne spremenljivke.
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
double VrednostOdprtihPozicij()
{
  double vrednost = 0;
  bool   stonoga  = false;
  if( braven != NEVELJAVNO ) 
  { 
    for( int i = 0; i < MAX_POZ; i++) 
    { 
      if( ( bpozicije[ i ] != PROSTO ) && ( bpozicije[ i ] != ZASEDENO ) ) 
      { 
        if( stonoga == true ) { vrednost = vrednost + VrednostPozicije( bpozicije[ i ] ); } else { stonoga = true; } 
      }
    }
    return( vrednost );
  }
  if( sraven != NEVELJAVNO ) 
  { 
    for( int j = 0; j < MAX_POZ; j++) 
    { 
      if( ( spozicije[ j ] != PROSTO ) && ( spozicije[ j ] != ZASEDENO ) ) 
      { 
        if( stonoga == true ) { vrednost = vrednost + VrednostPozicije( spozicije[ j ] ); } else { stonoga = true; }
      } 
    }
    return( vrednost );
  }
  return( vrednost );
} // VrednostOdprtihPozicij



/*--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
FUNKCIJA: ZapriPozicijo( int id )
---------------------------------
(o) Funkcionalnost: Zapre pozicijo z oznako id po trenutni tržni ceni.
(o) Zaloga vrednosti:
 (-) true: če je bilo zapiranje pozicije uspešno;
 (-) false: če zapiranje pozicije ni bilo uspešno; 
(o) Vhodni parametri: id - oznaka pozicije.
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
bool ZapriPozicijo( int id )
{
  int Rezultat;

  Rezultat = OrderSelect( id, SELECT_BY_TICKET );
  if( Rezultat == false ) 
    { Print( "M5-V", verzija, ":[", stevilkaIteracije, "]:", ":ZapriPozicijo::NAPAKA: Pozicije ", id, " ni bilo mogoče najti. Preveri pravilnost delovanja algoritma." ); return( false ); }
  switch( OrderType() )
  {
    case OP_BUY : return( OrderClose ( id, OrderLots(), Bid, 0, Green ) );
    case OP_SELL: return( OrderClose ( id, OrderLots(), Ask, 0, Red   ) );
    default:      return( OrderDelete( id ) );
  }  
} // ZapriPozicijo



/*
****************************************************************************************************************************************************************************************
*                                                                                                                                                                                      *
* SERVISNE FUNKCIJE                                                                                                                                                                    *
* Urejene po abecednem vrstnem redu                                                                                                                                                    *
*                                                                                                                                                                                      *
* Servisnih funkcij algoritem ne uporablja, služijo kot pripomočki, kadar gre pri izvajanju algoritma kaj narobe. Vstavi se jih v blok namenjen servisnim funkcijam znotraj init       *
****************************************************************************************************************************************************************************************
*/

/*--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
FUNKCIJA: PrepisiZapisIteracije( int stIteracije, double dd, double rr, double cc, double LL, double pp, int spz, string imeKopije )
(o) Funkcionalnost: 
 (-) preimenuje datoteko, ki hrani podatke o iteraciji stIteracije v datoteko z imenom podanim v parametru imeKopije
 (-) ponovno zapiše datoteko s podatki o iteraciji s podatki podanimi v parametrih funkcije:
  (*) razdalja med osnovnima ravnema - dd
  (*) razdalja med dodatnimi ravnmi za prodajo ali nakup - rr
  (*) začetna cena - cc
  (*) velikost pozicij v lotih - LL
  (*) profitni cilj - pp
  (*) indikator samodejnega ponovnega zagona - spz
(o) Zaloga vrednosti:
 (-) USPEH  - prepis datoteke je bil uspešen
 (-) NAPAKA - prepis datoteke ni bil uspešen
(o) Vhodni parametri: 
  (*) stIteracije - številka iteracije, katere datoteko bomo prepisali.
  (*) dd, rr, cc, LL, pp, spz - so opisani že zgoraj
  (*) imeKopije cena - cena, ki jo shranimo kot začetno ceno iteracije
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
bool PrepisiZapisIteracije( int stIteracije, double dd, double rr, double cc, double LL, double pp, int spz, double slo, string imeKopije )
{
  int    rocajDatoteke;
  string imeDatoteke;

  imeDatoteke = StringConcatenate( "M5-", stIteracije, ".dat" );
  if( FileMove( imeDatoteke, 0, imeKopije, FILE_REWRITE ) == false ) 
  { 
    Print( "M5-V", verzija, ":PrepisiZapisIteracije:USODNA NAPAKA: Preimenovanje datoteke ", imeDatoteke, " ni bilo uspešno. Koda napake: ", GetLastError() ); return( NAPAKA );
  }
  
  rocajDatoteke = FileOpen( imeDatoteke, FILE_WRITE|FILE_BIN );
  if( rocajDatoteke != INVALID_HANDLE)
  {
    FileWriteDouble ( rocajDatoteke, dd  );
    FileWriteDouble ( rocajDatoteke, rr  );
    FileWriteDouble ( rocajDatoteke, cc  );
    FileWriteDouble ( rocajDatoteke, LL  );
    FileWriteDouble ( rocajDatoteke, pp  );
    FileWriteInteger( rocajDatoteke, spz );
    FileWriteDouble ( rocajDatoteke, slo );
    Print( "Zapisovanje stanja iteracije ", stIteracije, " v datoteko ", imeDatoteke, ": -------------------------------------------------------------------------" );
    Print( "  Razdalja med osnovnima ravnema za nakup in prodajo [d]: ",          DoubleToString( dd, 5 ) );
    Print( "  Razdalja med dodatnimi ravnmi za nakup in prodajo [r]: ",           DoubleToString( rr, 5 ) );
    Print( "  Začetna cena [cz]: ",                                               DoubleToString( cc, 5 ) );
    Print( "  Velikost pozicij v lotih [L]: ",                                    DoubleToString( LL, 5 ) );
    Print( "  Profitni cilj [p]: ",                                               DoubleToString( pp, 5 ) );
    Print( "  Indikator samodejnega ponovnega zagona [samodejniPonovniZagon]: ", spz );
    Print( "  Odmik stop loss [odmikSL]: ",                                      DoubleToString( slo, 5 ) );
    Print( "--------------------------------------------------------------------------------------------------------------------------------------------" );
    FileClose( rocajDatoteke );
  }
  else 
  { Print( "M5-V", verzija, ":ShraniIteracijo:USODNA NAPAKA: Odpiranje datoteke ", imeDatoteke, " ni bilo uspešno." ); return( NAPAKA ); }
  return( USPEH );
} // PrepisiZapisIteracije



/*
****************************************************************************************************************************************************************************************
*                                                                                                                                                                                      *
* FUNKCIJE DKA                                                                                                                                                                         *
*                                                                                                                                                                                      *
****************************************************************************************************************************************************************************************
*/



/*--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
FUNKCIJA DKA: S0CakanjeNaZagon() 
----------------------------
V to stanje vstopimo po zaključenem nastavljanju začetnih vrednosti, če je v parametru cz podana zahtevana cena za zagon. V tem stanju čakamo, da bo cena valutnega para 
dosegla zahtevano ceno. 
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
int S0CakanjeNaZagon()
{
  if( cz == 0 ) { cz = cenaObZagonu; Print( "M5V", verzija, ":[", stevilkaIteracije, "]:", ":S0CakanjeNaZagon: Začetna cena [cz] = ", DoubleToString( cz, 5 ) ); return( S1 ); }
  if( ( ( cenaObZagonu >= cz ) && ( Bid <= cz ) ) || ( ( cenaObZagonu <= cz ) && ( Bid >= cz ) ) ) { return( S1 ); }
  else                                                                                             { return( S0 ); }
} // S0CakanjeNaZagon



/*--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
FUNKCIJA DKA: S1ZacetnoStanje()
V tem stanju se znajdemo, ko je valutni par dosegel ceno zahtevano v parametru cz (prehod iz stanja S0) oziroma v primeru, da je bil parameter cz ob zagonu algoritma enak 0, 
postane trenutna vrednost cz, trenutna cena (Bid) valutnega para. V tem stanju čakamo, da bo dosežena bodisi osnovna raven za nakup b0 ali osnovna raven za prodajo s0. 
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
int S1ZacetnoStanje()
{ 
  if( Bid >= ceneBravni[ 0 ] ) { bpozicije[ 0 ] = OdpriPozicijo( OP_BUY,  ceneSravni[ 0 ], 0 ); braven = 0; sraven = NEVELJAVNO; return( S2 ); }
  if( Ask <= ceneSravni[ 0 ] ) { spozicije[ 0 ] = OdpriPozicijo( OP_SELL, ceneBravni[ 0 ], 0 ); sraven = 0; braven = NEVELJAVNO; return( S3 ); }
  return( S1 );
} // S1ZacetnoStanje



/*--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
FUNKCIJA DKA: S2Nakup()
V tem stanju se znajdemo, ko je cena valutnega para dosegla osnovno raven za nakup in velja braven ≥ 0 . V vsakem trenutku je odprta najmanj ena pozicija buy. V tem stanju 
spremljamo raven na kateri se nahajamo in ustrezno vzdržujemo odprte buy pozicije. 
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
int S2Nakup()
{ 
  int    i;         // števec  
  string sporocilo; // string za sporočilo, ki ga pošljemo ob doseženem profitnem cilju
  bool   stonoga;   // pomožna spremenljivka - hrani informacijo ali smo pustili eno pozicijo za stonogo
  
  // prehod v stanje S3 - Prodaja
  if( Ask <= ceneSravni[ 0 ] ) 
  { 
    for( i = 0; i < MAX_POZ; i++ ) 
    { 
      if( bpozicije[ i ] == ZASEDENO ) { bpozicije[ i ] = PROSTO; }
      if( bpozicije[ i ] != PROSTO   ) 
      { 
        if( PozicijaZaprta( bpozicije[ i ] ) == false ) { ZapriPozicijo( bpozicije[ i ] ); }
        izkupicekIteracije = izkupicekIteracije + VrednostPozicije( bpozicije[ i ] ); bpozicije[ i ] = PROSTO;  
      } 
    }
    spozicije[ 0 ] = OdpriPozicijo( OP_SELL, ceneBravni[ 0 ], 0 ); braven = NEVELJAVNO; sraven = 0; return( S3 );
  }  
  // prehod v stanje S4 - Zaključek
  skupniIzkupicek = izkupicekIteracije + VrednostOdprtihPozicij();
  if( skupniIzkupicek >= p )
  {
    stonoga = false;
    for( i = 0; i < MAX_POZ; i++ ) 
    { 
      if( bpozicije[ i ] == ZASEDENO ) { bpozicije[ i ] = PROSTO; }
      if( bpozicije[ i ] != PROSTO )   
      { 
        if( PozicijaZaprta( bpozicije[ i ] ) == false ) 
        { 
          if( stonoga == true ) { ZapriPozicijo( bpozicije[ i ] ); } else { PostaviSL( bpozicije[ i ], odmikSL ); stonoga = true; }; 
        } 
      }
    }
    sporocilo = "Kaching: " + Symbol() + " iteracija " + IntegerToString( stevilkaIteracije ) + "!!!!!";
    braven = NEVELJAVNO; sraven = NEVELJAVNO; SendNotification( sporocilo ); ck = Bid; return( S4 );
  }
  
  // dosežena je naslednja višja raven
  if( Bid >= ceneBravni[ braven + 1 ] )
  {
    if( ( bpozicije[ braven ] != PROSTO ) && ( bpozicije[ braven ] != ZASEDENO ) && ( PozicijaZaprta( bpozicije[ braven ] ) == false ) ) { PostaviSL( bpozicije[ braven ], odmikSL ); }
    if( bpozicije[ braven+1 ] == PROSTO ) { bpozicije[ braven + 1 ] = OdpriPozicijo( OP_BUY,  ceneSravni[ 0 ], braven + 1 ); }
    braven++;
    Print(  ":[", stevilkaIteracije, "]:", "Nova nakupna raven: ", braven, " @", DoubleToString( ceneBravni[ braven ], 5 ) );
  }
  
  // cena pade pod trenutno raven
  if( Bid <= ceneBravni[ braven ] )
  {
    if( bpozicije[ braven+1 ] == ZASEDENO ) { bpozicije[ braven+1 ] = PROSTO; }
    if( ( bpozicije[ braven ] != PROSTO ) && ( bpozicije[ braven ] != ZASEDENO ) && ( PozicijaZaprta( bpozicije[ braven ] ) == true ) ) 
    { izkupicekIteracije = izkupicekIteracije + VrednostPozicije( bpozicije[ braven ] ); bpozicije[ braven ] = ZASEDENO; }
    if( braven > 0 ) { braven--; Print( ":[", stevilkaIteracije, "]:", "Nova nakupna raven: ", braven, " @", DoubleToString( ceneBravni[ braven ], 5 ) );  };
  }
  
  // če je bil pri eni od pozicij dosežen stop loss takoj popravimo izkupiček iteracije
  for( i = 0; i < MAX_POZ; i++ )
  { 
    if( ( bpozicije[ braven ] != PROSTO ) && ( bpozicije[ braven ] != ZASEDENO ) && ( PozicijaZaprta( bpozicije[ braven ] ) == true ) ) 
    { 
      izkupicekIteracije = izkupicekIteracije + VrednostPozicije( bpozicije[ braven ] ); bpozicije[ braven ] = ZASEDENO; 
      if( bpozicije[ braven+1 ] == ZASEDENO ) { bpozicije[ braven+1 ] = PROSTO; }  
    }
  }
  return( S2 );
} // S2Nakup



/*--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
FUNKCIJA DKA: S3Prodaja()
V tem stanju se znajdemo, ko je cena valutnega para dosegla osnovno raven za prodajo in velja sraven ≥ 0 . V vsakem trenutku je odprta najmanj ena pozicija sell. V tem stanju 
spremljamo raven na kateri se nahajamo in ustrezno vzdržujemo odprte sell pozicije.  
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
int S3Prodaja()
{ 
  int i;            // števec  
  string sporocilo; // string za sporočilo, ki ga pošljemo ob doseženem profitnem cilju
  bool stonoga;     // pomožna spremenljivka - hrani informacijo ali smo pustili eno pozicijo za stonogo
  
  // prehod v stanje S2 - Nakup
  if( Bid >= ceneBravni[ 0 ] ) 
  { 
    for( i = 0; i < MAX_POZ; i++ ) 
    { 
      if( spozicije[ i ] == ZASEDENO ) { spozicije[ i ] = PROSTO; }
      if( spozicije[ i ] != PROSTO   ) 
      { 
        if( PozicijaZaprta( spozicije[ i ] ) == false ) { ZapriPozicijo( spozicije[ i ] ); }
        izkupicekIteracije = izkupicekIteracije + VrednostPozicije( spozicije[ i ] ); spozicije[ i ] = PROSTO;  
      } 
    }
    bpozicije[ 0 ] = OdpriPozicijo( OP_BUY, ceneSravni[ 0 ], 0 ); sraven = NEVELJAVNO; braven = 0; return( S2 );
  }
  // prehod v stanje S4 - Zaključek
  skupniIzkupicek = izkupicekIteracije + VrednostOdprtihPozicij();
  if( skupniIzkupicek >= p )
  {
    stonoga = false;
    for( i = 0; i < MAX_POZ; i++ ) 
    { 
      if( spozicije[ i ] == ZASEDENO ) { spozicije[ i ] = PROSTO; }
      if( spozicije[ i ] != PROSTO   ) 
      { 
        if( PozicijaZaprta( spozicije[ i ] ) == false ) 
        { 
          if( stonoga == true ) { ZapriPozicijo( spozicije[ i ] ); } else { PostaviSL( spozicije[ i ], odmikSL ); stonoga = true; };  
        } 
      }
    }
    sporocilo = "Kaching: " + Symbol() + " iteracija " + IntegerToString( stevilkaIteracije ) + "!!!!!";
    braven = NEVELJAVNO; sraven = NEVELJAVNO; SendNotification( "Kaching!!!!" ); ck = Bid; return( S4 );
  }
  // dosežena je naslednja višja raven
  if( Ask <= ceneSravni[ sraven + 1 ] )
  {
    if( ( spozicije[ sraven ] != PROSTO ) && ( spozicije[ sraven ] != ZASEDENO ) && ( PozicijaZaprta( spozicije[ sraven ] ) == false ) ) { PostaviSL( spozicije[ sraven ], odmikSL ); }
    if( spozicije[ sraven+1 ] == PROSTO ) { spozicije[ sraven + 1 ] = OdpriPozicijo( OP_SELL,  ceneBravni[ 0 ], sraven + 1 ); }
    sraven++;
    Print( ":[", stevilkaIteracije, "]:", "Nova prodajna raven: ", sraven, " @", DoubleToString( ceneSravni[ sraven ], 5 ) );
  }
  // cena pade pod trenutno raven
  if( Ask >= ceneSravni[ sraven ] )
  {
    if( spozicije[ sraven+1 ] == ZASEDENO ) { spozicije[ sraven+1 ] = PROSTO; }
    if( ( spozicije[ sraven ] != PROSTO ) && ( spozicije[ sraven ] != ZASEDENO ) && ( PozicijaZaprta( spozicije[ sraven ] ) == true ) ) 
    { izkupicekIteracije = izkupicekIteracije + VrednostPozicije( spozicije[ sraven ] ); spozicije[ sraven ] = ZASEDENO; }
    if( sraven > 0 ) { sraven--; Print( ":[", stevilkaIteracije, "]:", "Nova prodajna raven: ", sraven, " @", DoubleToString( ceneSravni[ sraven ], 5 ) ); }
  }
  // če je bil pri eni od pozicij dosežen stop loss takoj popravimo izkupiček iteracije in označimo pozicijo eno raven višje kot prosto
  for( i = 0; i < MAX_POZ; i++ )
  { 
    if( ( spozicije[ sraven ] != PROSTO ) && ( spozicije[ sraven ] != ZASEDENO ) && ( PozicijaZaprta( spozicije[ sraven ] ) == true ) ) 
    { 
      izkupicekIteracije = izkupicekIteracije + VrednostPozicije( spozicije[ sraven ] ); spozicije[ sraven ] = ZASEDENO; 
      if( spozicije[ sraven+1 ] == ZASEDENO ) { spozicije[ sraven+1 ] = PROSTO; } 
    }
  }
  
  return( S3 );
} // S3Prodaja



/*--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
FUNKCIJA DKA: S4Zakljucek()
V tem stanju se znajdemo, ko je bil dosežen profitni cilj. Če je vrednost parametra samodejni zagon enaka NE, potem v tem stanju ostanemo, dokler uporabnik ročno ne prekine delovanja 
algoritma. Če je vrednost parametra samodejni zagon enaka DA, potem ustrezno ponastavimo stanje algoritma in ga ponovno poženemo.
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
int S4Zakljucek()
{ 
  if( ( samodejniPonovniZagon > 0 ) && ( IzpolnjenPogojZaPonovniZagon() == true ) ) { cz = 0; n = 0; init(); return( S0 ); } else { return( S4 ); }
} // S4Zakljucek