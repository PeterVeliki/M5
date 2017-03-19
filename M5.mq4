/*
****************************************************************************************************************************************************************************************
*                                                                                                                                                                                      *
* M5.mq4                                                                                                                                                                               *
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
extern int    stonoga;               // Način stonoge (milipede) vklopljen (1) oziroma izklopljen (0)



// Globalne konstante ------------------------------------------------------------------------------------------------------------------------------------------------------------------
#define MAX_POZ     99  // največje možno število odprtih pozicij v eno smer;
#define PROSTO     -1   // oznaka za vsebino polja bpozicije / spozicije;
#define ZASEDENO   -2   // oznaka za vsebino polja bpozicije / spozicije;
#define NEVELJAVNO -3   // oznaka za vrednost spremenljivk braven / sraven;
#define USPEH      -4   // oznaka za povratno vrednost pri uspešno izvedenem klicu funkcije;
#define NAPAKA     -5   // oznaka za povratno vrednost pri neuspešno izvedenem klicu funkcije;
#define ZE_OBSTAJA -6   // pri dodajanju pozicije v vrsto se je izkazalo, da je pozicija že v vrsti;
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
double izkupicekIteracije;  // Izkupiček trenutne iteracije algoritma (izkupiček zaprtih pozicij)
int    kslVrsta;            // Kazalec na naslednje prosto mesto v polju slVrsta
double maxIzpostavljenost;  // Največja izguba algoritma (minimum od izkupickaIteracije);
double skupniIzkupicek;     // Hrani trenutni skupni izkupiček trenutne iteracije, vključno z vrednostjo trenutno odprtih pozicij
int    slVrsta   [MAX_POZ]; // Hrani id-je vseh pozicij, pri katerih postavljanje stop loss ukazov ni bilo uspešno
int    spozicije [MAX_POZ]; // Enolične oznake vseh odprtih prodajnih pozicij;
int    sraven;              // Trenutna raven na prodajni strani. Če je cena trenutno na nakupni strani, potem ima spremenljivka vrednost NEVELJAVNO.
int    stanje;              // Trenutno stanje algoritma;
int    stevilkaIteracije;   // Številka trenutne iteracije;
int    verzija = 11;        // Trenutna verzija algoritma;



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
  cz = CenaIndikatorja();
  cenaObZagonu = Bid;
  
  if( n == 0 ) // Številka iteracije ni podana - začnemo novo iteracijo
  { 
    PonastaviVrednostiPodatkovnihStruktur();
    stevilkaIteracije = OdpriNovoIteracijo();
    if( stevilkaIteracije == NAPAKA ) 
      { Print( "M5-V", verzija, ":init:USODNA NAPAKA: pridobivanje številke iteracije ni uspelo. Delovanje ustavljeno." ); stanje = S4; samodejniPonovniZagon = 0; return( NAPAKA ); }
      else                           
      { 
        Print( "M5-V", verzija, ":init:Odprta nova iteracija št. ", stevilkaIteracije ); n = stevilkaIteracije; 
        ChartRedraw();
        NarisiCrto( clrRed, "zacetnaCena", cz );
        NarisiCrto( clrGreen, "nakupnaRaven", ceneBravni[ 0 ] );
        NarisiCrto( clrGreen, "prodajnaRaven", ceneSravni[ 0 ] );
        ChartRedraw();
        stanje = S0; return( USPEH ); 
      }
  }
  else         // Številka iteracije je podana - nadaljujemo z obstoječo iteracijo
  {
    stevilkaIteracije = n;
    kslVrsta          = 0; // vrsta pozicij katerim je treba ponastaviti SL se ne shranjuje, zato je na začetku prazna
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
           "Največja izpostavljenost: ", DoubleToString( maxIzpostavljenost,  5 ), " \n",
           "ceneBravni[0]: ",            DoubleToString( ceneBravni[0],       5 ), " \n",
           "ceneSravni[0]: ",            DoubleToString( ceneSravni[0],       5 ), " \n",
           "braven: ",                   braven,                                   " \n",
           "sraven: ",                   sraven );
           
  
  // če vrsta pozicij za ponastavljanje stop loss-ov ni prazna, poskusimo ponastaviti stop-loss-e
  if( kslVrsta > 0 ) { PreveriSL(); }
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
FUNKCIJA: CenaIndikatorja()
-------------------------------------
(o) Funkcionalnost: Vrne trenutno vrednost indikatorja supertrend.  
(o) Zaloga vrednosti: cena
(o) Vhodni parametri: / 
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
double CenaIndikatorja()
{
    double BuyLine;
    double SellLine;

    BuyLine  = iCustom( NULL, 0,"sa_MTEI_Supertrend", 0, 1 );
    SellLine = iCustom( NULL, 0,"sa_MTEI_Supertrend", 1, 1 );

    if( SellLine != EMPTY_VALUE ) 
    { 
      return ( SellLine );
    }
    if( BuyLine != EMPTY_VALUE )
    {
      return ( BuyLine );
    }
    Print( "CenaIndikatorja::Napaka - obe vrednosti indikatorja sta prazni!" );    
    return ( NAPAKA );
} // konec CenaIndikatorja



/*--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
FUNKCIJA: DodajVVrsto( int id )
-------------------------------------
(o) Funkcionalnost: V vrsto slVrsta doda pozicijo z oznako id, če le-te še ni v vrsti.  
(o) Zaloga vrednosti:
  (-) USPEH: pozicija je bila dodana v vrsto;
  (-) ZE_OBSTAJA: pozicija v vrsti že obstaja, dodajanje ni potrebno;
  (-) NAPAKA: pri dodajanju pozicije je prišlo do napake.
(o) Vhodni parametri: id: oznaka pozicije. 
(o) Uporabljene globalne spremenljivke:
  (-) kslVrsta: kazalec na naslednje prosto mesto v vrsti slVrsta;
  (-) slVrsta: vrsta v katero shranjujemo id-je pozicij.
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
int DodajVVrsto( int id )
{
   int i; // števec
   
   for( i = 0; i < kslVrsta; i++ )
   {
     if( slVrsta[ i ] == id ) { return( ZE_OBSTAJA ); }
   }
   // če smo prišli do sem, potem pozicije id v vrsti še ni in jo dodamo, če je še prostor v vrsti
   if( kslVrsta < MAX_POZ ) // preverimo 
   { 
     slVrsta[ kslVrsta ] = id;
     Print( "M5-V", verzija, ":[", stevilkaIteracije, "]:", ":DodajVVrsto: Pozicija ", Symbol(), ": ", i, " dodana v vrsto za ponastavitev SL." );
     kslVrsta++; return( USPEH ); 
   }
   else                       
   { 
     Print ( "M5-V", verzija, ":[", stevilkaIteracije, "]:", ":DodajVVrsto:OPOZORILO: Vrsta slVrsta je polna. Preveri pravilnost delovanja algoritma!!!!" );
     return( NAPAKA );
   }
} // DodajVVrsto


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
FUNKCIJA: IzpolnjenPogojZaPremikRavni
-------------------------------------
(o) Funkcionalnost: preveri ali je izpolnjen pogoj, da prestavimo raven za 1 navzgor ali navzdol. Pogoj za premik je izpolnjen, ko je cena indikatorja Supertrend presegla sredino med 
    naslednjima dvema nivojema v smeri navzgor ali navzdol.
(o) Zaloga vrednosti:
  (-) NEVELJAVNO: v primeru, ko pogoj za premik ni izpolnjen;
  (-) OP_BUY: v primeru, ko je potrebno premakniti ravni navzgor;
  (-) OP_SELL: v primeru, ko je potrebno premakniti ravni navzdol.
(o) Vhodni parametri: /
  (-) uporablja globalno spremenljivko cz
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
int IzpolnjenPogojZaPremikRavni()
{
   double mejnaCenaBuy;
   double mejnaCenaSell;
   double cenaIndikatorja;
   
   // izračunam mejne cene za premik ravni
   mejnaCenaBuy    = ( ceneBravni[1] + ceneBravni[0] )/2;
   mejnaCenaSell   = ( ceneSravni[1] + ceneSravni[0] )/2;
   
   // shranim ceno indikatorja, ker jo bom potreboval večkrat
   cenaIndikatorja = CenaIndikatorja();
   
   // preverim ali je izpolnjen kateri od pogojev za premik ravni
   if( cenaIndikatorja > mejnaCenaBuy  ) { return( OP_BUY ); }
   if( cenaIndikatorja < mejnaCenaSell ) { return( OP_SELL ); }
   
   // v primeru da ni bil izpolnjen noben od pogojev vrnem 0
   return( NEVELJAVNO );
} // IzpolnjenPogojZaPremikRavni



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
    braven = NEVELJAVNO; sraven = NEVELJAVNO; Print( ":[", stevilkaIteracije, "]:", "Stanje algoritma je neodločeno, izbrano stanje: ", ImeStanja( S2 ) ); return( S2 ); 
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
FUNKCIJA: OdstraniIzVrste( int id )
---------------------------
(o) Funkcionalnost: Odstrani pozicijo z oznako id iz vrste slVrsta
(o) Zaloga vrednosti: 
  (-) USPEH: pozicija odstranjena
  (-) NAPAKA: odstranjevanje pozicije ni uspelo, ker je v vrsti ni bilo.
(o) Vhodni parametri: id - oznaka pozicije za brisanje iz vrste
(o) Uporabljene globalne spremenljivke:
  (-) kslVrsta: kazalec na naslednje prosto mesto v vrsti slVrsta;
  (-) slVrsta: vrsta v katero shranjujemo id-je pozicij.
------------------------------------------------------- ------------------------------------------------------------------------------------------------------------------------------*/
int OdstraniIzVrste( int id )
{
  int i;                // števec 
  bool pozicijaNajdena; // števec
  
  pozicijaNajdena = false;
  for( i = 0; i < kslVrsta; i++ )
  {
    if( slVrsta[ i ]    == id   ) { pozicijaNajdena = true;        }
    if( pozicijaNajdena == true ) { slVrsta[ i ] = slVrsta[ i+1 ]; }                          
  }
  if( pozicijaNajdena == true ) 
  { 
    Print( "M5-V", verzija, ":[", stevilkaIteracije, "]:", ":OdstraniIzVrste: Pozicija ", Symbol(), ": ", i, " odstranjena iz vrste za ponastavitev SL." );
    kslVrsta--; return( USPEH ); } else { return( NAPAKA ); 
  }
} // OdstraniIzVrste


/*--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
FUNKCIJA: OsveziCeneRavni( c )
---------------------------
(o) Funkcionalnost: Nastavi cene ravni v poljih ceneBravni in ceneSravni, glede na podano začetno ceno
(o) Zaloga vrednosti: USPEH (vedno uspe)
(o) Vhodni parametri: začetna cena
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
int OsveziCeneRavni( double c )
{
  ceneBravni[ 0 ] = c + d/2; Print( ":[", stevilkaIteracije, "]:", "Nakupna raven 0: ",  DoubleToString( ceneBravni[ 0 ], 5 ) );
  ceneSravni[ 0 ] = c - d/2; Print( ":[", stevilkaIteracije, "]:", "Prodajna raven 0: ", DoubleToString( ceneSravni[ 0 ], 5 ) );
  for( int i = 1; i < MAX_POZ; i++ ) { ceneBravni[ i ] = ceneBravni[ i-1 ] + r; ceneSravni[ i ] = ceneSravni[ i-1 ] - r; }
  return( USPEH );
} // OsveziCeneRavni



/*--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
FUNKCIJA: PoisciNajvecVrednoPozicijo
------------------------------------
(o) Funkcionalnost: Funkcija poišče največ vredno pozicijo na nasprotni strani. 
 (-) če je podan parameter OP_BUY,  potem poišče nakupno  pozicijo v polju spozicije. Vrne tisto z najvišjim indeksom. Če je ne najde, potem vrne 0.
 (-) če je podan parameter OP_SELL, potem poišče prodajno pozicijo v polju bpozicije. Vrne tisto z najvišjim indeksom. Če je ne najde, potem vrne 0.
(o) Zaloga vrednosti: 
 (-) id pozicije: če je pozicija bila najdena
 (-) 0: pozicija ni bila najdena
(o) Vhodni parametri: OP_BUY ali OP_SELL. 
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
int PoisciNajvecVrednoPozicijo( int smer )
{
   int i;
   int selectRezultat;
   int pozicija;
   
   pozicija = 0;
   if( smer == OP_BUY )
   {
     for( i = 0; i < MAX_POZ; i++ )
     {
       if( ( spozicije[ i ] != PROSTO ) && ( spozicije[ i ] != ZASEDENO ) )
       {
         selectRezultat = OrderSelect( spozicije[ i ], SELECT_BY_TICKET );
         if( selectRezultat == false  ) { Print( "M5-V", verzija, ":[", stevilkaIteracije, "]:",  ":PoisciNajvecVrednoPozicijo:NAPAKA: Pozicije ", spozicije[ i ], " ni bilo mogoče najti. Preveri pravilnost delovanja algoritma." ); return( NAPAKA ); }
         if( OrderType()    == OP_BUY ) { pozicija = spozicije[ i ]; }
       }
     }
   }   
   else // smer == OP_SELL
   {
     for( i = 0; i < MAX_POZ; i++ )
     {
       if( ( bpozicije[ i ] != PROSTO ) && ( bpozicije[ i ] != ZASEDENO ) )
       {
         selectRezultat = OrderSelect( bpozicije[ i ], SELECT_BY_TICKET );
         if( selectRezultat == false  )  { Print( "M5-V", verzija, ":[", stevilkaIteracije, "]:",  ":PoisciNajvecVrednoPozicijo:NAPAKA: Pozicije ", bpozicije[ i ], " ni bilo mogoče najti. Preveri pravilnost delovanja algoritma." ); return( NAPAKA ); }
         if( OrderType()    == OP_SELL ) { pozicija = bpozicije[ i ]; }
       }
     }
   }
   return( pozicija );
} // PoisciNajvecVrednoPozicijo



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
  braven             = NEVELJAVNO;
  sraven             = NEVELJAVNO;
  izkupicekIteracije = 0;
  skupniIzkupicek    = 0;
  ck                 = 0;
  kslVrsta           = 0;
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

  selectRezultat = OrderSelect( id, SELECT_BY_TICKET );
  if( selectRezultat == false ) 
  { 
    Print( "M5-V", verzija, ":[", stevilkaIteracije, "]:",  ":PostaviSL:NAPAKA: Pozicije ", id, " ni bilo mogoče najti. Preveri pravilnost delovanja algoritma." ); return( NAPAKA ); 
  }
  
  if( OrderType() == OP_BUY ) { if( OrderStopLoss() == OrderOpenPrice() + odmik ) { return( USPEH ); } else { ciljniSL = OrderOpenPrice() + odmik; } }
  else                        { if( OrderStopLoss() == OrderOpenPrice() - odmik ) { return( USPEH ); } else { ciljniSL = OrderOpenPrice() - odmik; } }
  
  modifyRezultat = OrderModify( id, OrderOpenPrice(), ciljniSL, 0, 0, clrNONE );
  if( modifyRezultat == false ) 
  { 
    Print( "M5-V", verzija, ":[", stevilkaIteracije, "]:", ":PostaviSL:OPOZORILO: Pozicije ", id, " ni bilo mogoče ponastaviti SL. Koda napake: ", GetLastError() ); 
    Print( "M5-V", verzija, ":[", stevilkaIteracije, "]:", ":PostaviSL:Obstoječi SL = ", DoubleToString( OrderStopLoss(), 5 ), " Ciljni SL = ", DoubleToString( ciljniSL, 5 ) );
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
(o) Funkcionalnost: ponastavi stanje algoritma po prekinitvi delovanja
 (-) nastavi začetno ceno algoritma cz na trenutno vrednost indikatorja;
 (-) izračune ravni na prodajni in nakupni strani;
 (-) inicializira spremenljivki sraven in braven
 (-) sešteje izkupiček vseh zaprtih pozicij, ki pripadajo iteraciji n in ga shrani v spremenljivko izkupiček iteracije
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
  // začetna cena je trenutna cena indikatorja
  cz = CenaIndikatorja();
  
  Print( "Branje stanja iteracije: -------------------------------------------------------------------------------------------------------------------" );
  Print( "  Razdalja med osnovnima ravnema za nakup in prodajo [d]: ",         DoubleToString( d,       5 ) );
  Print( "  Razdalja med dodatnimi ravnmi za nakup in prodajo [r]: ",          DoubleToString( r,       5 ) );
  Print( "  Začetna cena [cz]: ",                                              DoubleToString( cz,      5 ) );
  Print( "  Velikost pozicij v lotih [L]: ",                                   DoubleToString( L,       5 ) );
  Print( "  Profitni cilj [p]: ",                                              DoubleToString( p,       5 ) );
  Print( "  Indikator samodejnega ponovnega zagona [samodejniPonovniZagon]: ", samodejniPonovniZagon        );
  Print( "  Odmik stop loss [odmikSL]: ",                                      DoubleToString( odmikSL, 5 ) );
  Print( "--------------------------------------------------------------------------------------------------------------------------------------------" );
  
  izkupicekIteracije = IzkupicekZaprtihPozicijIteracije( stIteracije ); Print( "  Izkupicek iteracije: ", DoubleToString( izkupicekIteracije, 5 ) );
  skupniIzkupicek    = izkupicekIteracije;
  OsveziCeneRavni( cz );
  SprostiPozicije( OP_BUY  );
  SprostiPozicije( OP_SELL );
  VpisiOdprtePozicije( stIteracije );
  return( USPEH );
} // PreberiIteracijo



/*--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
FUNKCIJA: PrestaviRavni()
-------------------------
(o) Funkcionalnost: funkcija prestavi ravni eno raven višje ali nižje, odvisno od vhodnega parametra. Če je vhodni parameter OP_BUY, začetno ceno dvignem za eno raven. Sicer jo za eno
    raven spustimo.
(o) Zaloga vrednosti: funkcija vedno vrne TRUE.
(o) Vhodni parametri: 
  (-) OP_BUY: ravni premaknemo eno raven višje
  (-) OP_SELL: ravni premaknemo eno raven nižje
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
bool PrestaviRavni( int smer )
{
   int i;
   int rezultat;
   if( smer == OP_SELL )
   { 
      // prestavimo vse nakupne pozicije eno raven višje in na prvo nakupno raven vpišemo bivšo prodajno pozicijo osnovne ravni
      for( i = MAX_POZ-1; i > 0; i-- )   { bpozicije[i] = bpozicije[i-1]; } 
      bpozicije[ 0 ] = spozicije[ 0 ];
      rezultat = PostaviSL( bpozicije[ 0 ], odmikSL );
      if( rezultat != USPEH ) { Print( "M5-V", verzija, ":[", stevilkaIteracije, "]:", ":PrestaviRavni:INFO: Postavljanje SL pozicije ", bpozicije[ 0 ], " ni uspelo. Pozicija dodana v vrsto za kasnejše nastavljanje." ); }
      
      // prestavimo vse prodajne pozicije eno raven nižje
      for( i = 0; i < (MAX_POZ-1); i++ ) { spozicije[i] = spozicije[i+1];} 
      spozicije[MAX_POZ-1] = PROSTO; 
           
      // ponastavimo začetno ceno in cene začetnih ravni
      cz = ceneSravni[ 0 ] - d/2;
      OsveziCeneRavni( cz );
   }
   if( smer == OP_BUY ) 
   {
      // prestavimo vse prodajne pozicije eno raven višje in na prvo prodajno raven vpišemo bivšo nakupno pozicijo osnovne ravni
      for( i = MAX_POZ-1; i > 0; i-- )   { spozicije[i] = spozicije[i-1]; } 
      spozicije[ 0 ] = bpozicije[ 0 ];
      rezultat = PostaviSL( spozicije[0], odmikSL );
      if( rezultat != USPEH ) { Print( "M5-V", verzija, ":[", stevilkaIteracije, "]:", ":PrestaviRavni:INFO: Postavljanje SL pozicije ", spozicije[ 0 ], " ni uspelo. Pozicija dodana v vrsto za kasnejše nastavljanje." ); }
      
      // prestavimo vse nakupne pozicije eno raven nižje
      for( i = 0; i < (MAX_POZ-1); i++ ) { bpozicije[i] = bpozicije[i+1]; } 
      bpozicije[MAX_POZ-1] = PROSTO; 
      
      // ponastavimo začetno ceno in cene začetnih ravni
      cz = ceneBravni[ 0 ] + d/2;
      OsveziCeneRavni( cz );
   }
   
   // ponastavimo še vrednosti spremenljivk ravni
   if( Ask <= ceneSravni[0] ) 
   { 
      braven = NEVELJAVNO; 
      i = 0;
      while( ceneSravni[i] >= Ask ) { i++; }
      sraven = i - 1;
   }
   if( Bid >= ceneBravni[0] ) 
   { 
     sraven = NEVELJAVNO;
     i = 0;
     while( ceneBravni[i] <= Bid ) { i++; }
     braven = i - 1;
   }
   
   // prestavimo črte na zaslonu
   PremakniCrto( "zacetnaCena", cz );
   PremakniCrto( "nakupnaRaven", ceneBravni[ 0 ] );
   PremakniCrto( "prodajnaRaven", ceneSravni[ 0 ] );
   ChartRedraw();
   
   return( true );
} // PrestaviRavni



/*--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
FUNKCIJA: PreveriSL()
----------------------
(o) Funkcionalnost: funkcija preveri ali je kateri od pozicij, katerih id-ji so shranjeni v polju (globalni spremenljivki) slVrsta, mogoče postaviti SL na razdaljo nastavljeno v 
    parametru algoritma odmikSL.
(o) Zaloga vrednosti: funkcija vedno vrne TRUE.
(o) Vhodni parametri: eksplicitnih parametrov ni, funkcija uporablja naslednje globalne spremenljivke:
  (-) kslVrsta - kazalec na naslednjo prosto mesto v polju slVrsta
  (-) slVrsta - polje, ki hrani id-je pozicij
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
bool PreveriSL()
{
  int i; // pomožna spremenljivka - števec
  
  for( i = 0; i < kslVrsta; i++ ) 
  { 
    if( PozicijaZaprta( slVrsta[ i ] ) == true ) { OdstraniIzVrste( i );                                                                 }
    else                                         
    { 
      if( SLMogocePostaviti( slVrsta[ i ] ) == true ) 
      { 
        if( PostaviSL( slVrsta[ i ], odmikSL ) == USPEH ) 
        { 
          OdstraniIzVrste( i ); // če je bilo postavljanje sl ukaza uspešno, potem pozicijo odstranimo iz vrste
        }
        else 
        { // v nasprotnem primeru izpišemo opozorilo - ponastavljanje bi v večini primerov namreč moralo uspeti
          Print( "M5-V", verzija, ":[", stevilkaIteracije, "]:", ":PreveriSL:OPOZORILO: Postavljanje SL pozicije ", slVrsta[ i ], " ni bilo uspešno. Preveri delovanje algoritma." );
        }
      }
    }
  }
  return( true );
} // PreveriSL



/*--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
FUNKCIJA: SLMogocePostaviti( id )
---------------------------------
(o) Funkcionalnost: 
  (-) poišče ceno odprtja pozicije;
  (-) odvisno od tega ali gre za buy ali sell pozicijo preveri ali velja, da je cena najmanj za stop level nad željenim SL (za buy pozicije) ali najmanj za stop level pod željenim SL 
     (za sell pozicije).
  (-) če je pogoj izpolnjen, vrne vrednost true, sicer vrne vrednost false
(o) Zaloga vrednosti:
  (-) true: stop loss je mogoče postaviti
  (-) false: stop lossa ni mogoče postaviti
(o) Vhodni parametri: id pozicije za katero preverjamo ali je stop loss mogoče postaviti
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
bool SLMogocePostaviti( int id )
{
  double openPrice;
  double level;
  int    selectRezultat;

  level = MarketInfo( Symbol(), MODE_STOPLEVEL ) * Point;
  selectRezultat = OrderSelect( id, SELECT_BY_TICKET );
  if( selectRezultat == false ) 
  { 
    Print( "M5-V", verzija, ":[", stevilkaIteracije, "]:",  ":SLMogocePostaviti:NAPAKA: Pozicije ", id, " ni bilo mogoče najti. Preveri pravilnost delovanja algoritma." ); return( false ); 
  }
  openPrice = OrderOpenPrice();
  if( OrderType() == OP_BUY ) { if( Bid > ( openPrice + odmikSL + level ) ) { return( true ); } else { return( false ); } }
  else                        { if( Ask < ( openPrice - odmikSL - level ) ) { return( true ); } else { return( false ); } }
  Print( "M5-V", verzija, ":[", stevilkaIteracije, "]:", ":SLMogocePostaviti:OPOZORILO: Ta stavek se nikoli ne bi smel izvesti - preveri pravilnost delovanja algoritma." );  
} // SLMogocePostaviti



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
(o) Funkcionalnost: pregleda vse trenutno odprte pozicije in tiste, ki pripadajo iteraciji st vpiše na ustrezno raven v tabelah bpozicije / spozicije
(o) Zaloga vrednosti: USPEH (vedno uspe)
(o) Vhodni parametri: st - številka iteracije
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
int VpisiOdprtePozicije( int st )
{
  int    magicNumberN; // hramba za magic number ukaza, ki ga trenutno obdelujemo
  int    stIteracijeI; // hramba za stevilko iteracije ukaza, ki ga trenutno obdelujemo
  int    ravenK;       // hramba za raven ukaza, ki ga trenutno obdelujemo
  int    stUkazov;     // stevilo odprtih pozicij v terminalu
  int    i;            // števec
  int    j;            // števec

  stUkazov  = OrdersTotal();
  for( j = 0; j < stUkazov; j++ )
  {
    if( OrderSelect( j, SELECT_BY_POS ) == false ) 
    { Print( "M5-V", verzija, ":VpisiOdprtePozicije:OPOZORILO: Napaka pri dostopu do odprtih pozicij." ); } 
    else                   
    {
      magicNumberN = OrderMagicNumber();
      ravenK       = magicNumberN % 100;
      stIteracijeI = magicNumberN - ravenK;
      if( stIteracijeI == st ) 
      { 
        // našli smo pozicijo, ki pripada podani iteraciji
        if( OrderCloseTime() == 0 )
        { // pozicija ni zaprta
          if( OrderOpenPrice() <= cz )
          { // pozicijo bomo vpisali na prodajno stran
            i = 0;
            while( ( ceneSravni[ i ] >= OrderOpenPrice() ) && ( i < MAX_POZ ) )  { i++; }
            if( i == MAX_POZ-1 ) { Print( "M5-V", verzija, ":VpisiOdprtePozicije:OPOZORILO: pozicije ", OrderTicket(), " ni bilo mogoče vpisati na nobeno raven na prodajni strani." ); }
            else { spozicije[ i ] = OrderTicket(); Print( "  - pozicija ", OrderTicket(), " uspešno vpisana na prodajno raven ", i, "." ); }
          }
          else
          { // pozicijo bomo vpisali na nakupno stran
            i = 0;
            while( ( ceneBravni[ i ] <= OrderOpenPrice() ) && ( i < MAX_POZ ) )  { i++; }
            if( i == MAX_POZ-1 ) { Print( "M5-V", verzija, ":VpisiOdprtePozicije:OPOZORILO: pozicije ", OrderTicket(), " ni bilo mogoče vpisati na nobeno raven na nakupni strani." ); }
            else { bpozicije
            [ i ] = OrderTicket(); Print( "  - pozicija ", OrderTicket(), " uspešno vpisana na nakupno raven ", i, "." ); }
          }
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
  int najvecVrednaPozicija;
  
  // seštejemo vrednosti vseh pozicij
  for( int i = 0; i < MAX_POZ; i++) 
  { 
    if( ( bpozicije[ i ] != PROSTO ) && ( bpozicije[ i ] != ZASEDENO ) ) { vrednost = vrednost + VrednostPozicije( bpozicije[ i ] ); } 
    if( ( spozicije[ i ] != PROSTO ) && ( spozicije[ i ] != ZASEDENO ) ) { vrednost = vrednost + VrednostPozicije( spozicije[ i ] ); }
  }
  
  // če smo v načinu stonoge, potem največ vredno odprto pozicijo pustimo za stonogo, zato vrednost te pozicije odštejemo
  if( stonoga == 1 )
  {
    if( sraven == NEVELJAVNO ) 
    { 
      // ker smo trenutno na BUY strani, poiščamo največ vredno BUY pozicijo na nasprotni strani
      najvecVrednaPozicija = PoisciNajvecVrednoPozicijo( OP_BUY ); 
      // če na nasprotni strani ni nobene BUY pozicije, potem je največ vredna pozicija bpozicije[ 0 ]
      if( najvecVrednaPozicija == 0 ) { najvecVrednaPozicija = bpozicije[ 0 ]; }
      // odštejemo vrednost največ vredne pozicije
      vrednost = vrednost - VrednostPozicije( najvecVrednaPozicija ); 
    } 
    else // braven == NEVELJAVNO
    { 
      // ker smo trenutno na SELL strani, poiščemo največ vredno SELL pozicijo na nasprotni strani
      najvecVrednaPozicija = PoisciNajvecVrednoPozicijo( OP_SELL ); 
      // če na nasprotni strani ni nobene SELL pozicije, potem je največ vredna pozicija spozicije[ 0 ]
      if( najvecVrednaPozicija == 0 ) { najvecVrednaPozicija = spozicije[ 0 ]; }
      vrednost = vrednost - VrednostPozicije( najvecVrednaPozicija ); 
    }
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
* Funkcije za grafični prikaz osnovne cene in osnovnih ravni                                                                                                                           *
*                                                                                                                                                                                      *
****************************************************************************************************************************************************************************************
*/
bool NarisiCrto( color barva, string ime, double cena )
{

   ResetLastError(); 
   if(!ObjectCreate(0, ime, OBJ_HLINE, 0, 0, cena)) 
   { 
      Print(__FUNCTION__, ": failed to create a horizontal line! Error code = ",GetLastError()); 
      return(false); 
   }
   ObjectSetInteger(0, ime, OBJPROP_COLOR, barva); 
   ObjectSetInteger(0, ime, OBJPROP_STYLE, STYLE_SOLID); 
   ObjectSetInteger(0, ime, OBJPROP_WIDTH, 1); 
   ObjectSetInteger(0, ime, OBJPROP_BACK, false); 
   ObjectSetInteger(0, ime, OBJPROP_SELECTABLE, true); 
   ObjectSetInteger(0, ime, OBJPROP_SELECTED, true); 
   ObjectSetInteger(0, ime, OBJPROP_HIDDEN, true); 
   ObjectSetInteger(0, ime, OBJPROP_ZORDER, 0); 
   return(true); 
} // NarisiCrto


bool PremakniCrto( string ime, double cena )
{
   ResetLastError(); 
   if(!ObjectMove( 0, ime, 0, 0, cena ) ) 
   { 
      Print(__FUNCTION__, ": failed to move the horizontal line! Error code = ",GetLastError()); 
      return(false); 
   } 
   return(true); 
} // PremakniCrto



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
  double cenaIndikatorja;
  
  cenaIndikatorja = CenaIndikatorja();
  if( cenaIndikatorja != cz ) 
  { 
    OsveziCeneRavni( cenaIndikatorja ); 
    cz = cenaIndikatorja; 
    cenaObZagonu = Bid; 
    
    // prestavimo črte na zaslonu
    PremakniCrto( "zacetnaCena", cz );
    PremakniCrto( "nakupnaRaven", ceneBravni[ 0 ] );
    PremakniCrto( "prodajnaRaven", ceneSravni[ 0 ] );
    ChartRedraw();
  }
  if( ( ( ( cenaObZagonu >= cz ) && ( Bid <= cz ) ) || ( ( cenaObZagonu <= cz ) && ( Bid >= cz ) ) ) && ( TimeHour( TimeCurrent()) >= 8) ) { return( S1 ); }
  else                                                                                             { return( S0 ); }
} // S0CakanjeNaZagon



/*--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
FUNKCIJA DKA: S1ZacetnoStanje()
V tem stanju se znajdemo, ko je valutni par dosegel ceno zahtevano v parametru cz (prehod iz stanja S0) oziroma v primeru, da je bil parameter cz ob zagonu algoritma enak 0, 
postane trenutna vrednost cz, trenutna cena (Bid) valutnega para. V tem stanju čakamo, da bo dosežena bodisi osnovna raven za nakup b0 ali osnovna raven za prodajo s0. 
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
int S1ZacetnoStanje()
{ 
  if( Bid >= ceneBravni[ 0 ] ) { bpozicije[ 0 ] = OdpriPozicijo( OP_BUY,  0, 0 ); braven = 0; sraven = NEVELJAVNO; return( S2 ); }
  if( Ask <= ceneSravni[ 0 ] ) { spozicije[ 0 ] = OdpriPozicijo( OP_SELL, 0, 0 ); sraven = 0; braven = NEVELJAVNO; return( S3 ); }
  return( S1 );
} // S1ZacetnoStanje



/*--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
FUNKCIJA DKA: S2Nakup()
V tem stanju se znajdemo, ko je cena valutnega para dosegla osnovno raven za nakup in velja braven ≥ 0 . V vsakem trenutku je odprta najmanj ena pozicija buy. V tem stanju 
spremljamo raven na kateri se nahajamo in ustrezno vzdržujemo odprte buy pozicije. 
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
int S2Nakup()
{ 
  int    i;            // števec  
  string sporocilo;    // string za sporočilo, ki ga pošljemo ob doseženem profitnem cilju
  int    premikRavni;  // hrani informacijo ali je raven potrebno premakniti 
  int    najvecVredna; // hrani id največ vredne pozicije
  
  // preverimo ali je izpolnjen pogoj za premik ravni
  premikRavni = IzpolnjenPogojZaPremikRavni();
  if( premikRavni != NEVELJAVNO ) 
  { 
    PrestaviRavni( premikRavni ); 
    // test zapremo vse na drugi strani
    if( premikRavni == OP_BUY )
    {
      for( i = 0; i < MAX_POZ; i++ ) 
      { 
        // zapremo SELL pozicije
        if( spozicije[ i ] == ZASEDENO ) { spozicije[ i ] = PROSTO; }
        OrderSelect( spozicije[ i ], SELECT_BY_TICKET );
        if( ( OrderType() == OP_SELL ) && ( spozicije[ i ] != PROSTO ) ) { if( PozicijaZaprta( spozicije[ i ] ) == false ) { ZapriPozicijo( spozicije[ i ] ); } }
      }
    }
    if( premikRavni == OP_SELL )
    {
      for( i = 0; i < MAX_POZ; i++ ) 
      { 
        // zapremo BUY pozicije
        if( bpozicije[ i ] == ZASEDENO ) { bpozicije[ i ] = PROSTO; }
        OrderSelect( bpozicije[ i ], SELECT_BY_TICKET );
        if( ( OrderType() == OP_BUY) && ( bpozicije[ i ] != PROSTO ) ) { if( PozicijaZaprta( bpozicije[ i ] ) == false ) { ZapriPozicijo( bpozicije[ i ] ); } }
      }
    }
  }
  
  // prehod v stanje S3 - Prodaja
  if( Ask <= ceneSravni[ 0 ] ) 
  { 
    if( ( spozicije[ 0 ] == PROSTO ) || ( PozicijaZaprta( spozicije[ 0 ] ) == true ) ) { spozicije[ 0 ] = OdpriPozicijo( OP_SELL, 0, 0 ); } 
    braven = NEVELJAVNO; 
    sraven = 0; 
    return( S3 );
  }
    
  // prehod v stanje S4 - Zaključek
  skupniIzkupicek = izkupicekIteracije + VrednostOdprtihPozicij();
  if( skupniIzkupicek >= p )
  {
    if ( stonoga == 1 ) 
    {
      // poiščemo največ vredno BUY pozicijo na nasprotni strani
      najvecVredna = PoisciNajvecVrednoPozicijo( OP_BUY );
      // če na nasprotni strani ni nobene BUY pozicije, potem je največ vredna bpozicije[ 0 ]
      if( najvecVredna == 0 ) { najvecVredna = bpozicije[ 0 ]; }
    }
    else
    {
      najvecVredna = 0;
    }
  
    // zapremo vse pozicije razen najvec vredne (če je določena)
    for( i = 0; i < MAX_POZ; i++ ) 
    { 
      // zapremo BUY pozicijo
      if( bpozicije[ i ] == ZASEDENO ) { bpozicije[ i ] = PROSTO; }
      if( ( bpozicije[ i ] != PROSTO ) && ( bpozicije[ i ] != najvecVredna ) ) { if( PozicijaZaprta( bpozicije[ i ] ) == false ) { ZapriPozicijo( bpozicije[ i ] ); } } 
      // zapremo SELL pozicijo
      if( spozicije[ i ] == ZASEDENO ) { spozicije[ i ] = PROSTO; }
      if( ( spozicije[ i ] != PROSTO ) && ( spozicije[ i ] != najvecVredna ) ) { if( PozicijaZaprta( spozicije[ i ] ) == false ) { ZapriPozicijo( spozicije[ i ] ); } }
    }
    if ( stonoga == 1 ) { if( PostaviSL( najvecVredna, odmikSL ) == NAPAKA ) { DodajVVrsto( najvecVredna ); } }
    sporocilo = "M5-V"+verzija+":OBVESTILO: dosežen profitni cilj: " + Symbol() + " iteracija " + IntegerToString( stevilkaIteracije ) + ".";
    braven = NEVELJAVNO; sraven = NEVELJAVNO; SendNotification( sporocilo ); ck = Bid; return( S4 );
  }
  
  // dosežena je naslednja višja raven
  if( Bid >= ceneBravni[ braven + 1 ] )
  {
    if( ( bpozicije[ braven+1 ] == PROSTO ) || ( PozicijaZaprta( bpozicije[ braven+1 ] ) == true ) ) { bpozicije[ braven + 1 ] = OdpriPozicijo( OP_BUY,  0, braven + 1 ); }
    braven++;
    Print(  ":[", stevilkaIteracije, "]:", "Nova nakupna raven: ", braven, " @", DoubleToString( ceneBravni[ braven ], 5 ) );
  }
  
  // cena pade pod trenutno raven
  if( Bid <= ceneBravni[ braven ] )
  {
    if( braven > 0 ) { braven--; Print( ":[", stevilkaIteracije, "]:", "Nova nakupna raven: ", braven, " @", DoubleToString( ceneBravni[ braven ], 5 ) );  };
  }
  
  // če je bil pri eni od pozicij dosežen stop loss takoj popravimo izkupiček iteracije
  for( i = 0; i < MAX_POZ; i++ )
  { 
    if( ( bpozicije[ i ] != PROSTO ) && ( bpozicije[ i ] != ZASEDENO ) && ( PozicijaZaprta( bpozicije[ i ] ) == true ) ) 
    { 
      izkupicekIteracije = izkupicekIteracije + VrednostPozicije( bpozicije[ i ] ); bpozicije[ i ] = PROSTO; 
      Print( "Knjižen izkupiček iteracije - BUY" );
    }
    if( ( spozicije[ i ] != PROSTO ) && ( spozicije[ i ] != ZASEDENO ) && ( PozicijaZaprta( spozicije[ i ] ) == true ) ) 
    { 
      izkupicekIteracije = izkupicekIteracije + VrednostPozicije( spozicije[ i ] ); spozicije[ i ] = PROSTO; 
      Print( "Knjižen izkupiček iteracije - SELL" );
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
  int    i;            // števec  
  string sporocilo;    // string za sporočilo, ki ga pošljemo ob doseženem profitnem cilju
  int    premikRavni;  // hrani vrednost ali je potreben premik ravni in v katero smer
  int    najvecVredna; // hrani id največ vredne pozicije
  
  // preverimo ali je izpolnjen pogoj za premik ravni
  premikRavni = IzpolnjenPogojZaPremikRavni();
  if( premikRavni != NEVELJAVNO ) 
  { 
    PrestaviRavni( premikRavni ); 
    // test zapremo vse na drugi strani
    if( premikRavni == OP_BUY )
    {
      for( i = 0; i < MAX_POZ; i++ ) 
      { 
        // zapremo SELL pozicije
        if( spozicije[ i ] == ZASEDENO ) { spozicije[ i ] = PROSTO; }
        OrderSelect( spozicije[ i ], SELECT_BY_TICKET );
        if( ( OrderType() == OP_SELL ) && ( spozicije[ i ] != PROSTO ) ) { if( PozicijaZaprta( spozicije[ i ] ) == false ) { ZapriPozicijo( spozicije[ i ] ); } }
      }
    }
    if( premikRavni == OP_SELL )
    {
      for( i = 0; i < MAX_POZ; i++ ) 
      { 
        // zapremo BUY pozicije
        if( bpozicije[ i ] == ZASEDENO ) { bpozicije[ i ] = PROSTO; }
        OrderSelect( bpozicije[ i ], SELECT_BY_TICKET );
        if( ( OrderType() == OP_BUY) && ( bpozicije[ i ] != PROSTO ) ) { if( PozicijaZaprta( bpozicije[ i ] ) == false ) { ZapriPozicijo( bpozicije[ i ] ); } }
      }
    }
  }
  
  // prehod v stanje S2 - Nakup
  if( Bid >= ceneBravni[ 0 ] ) 
  { 
    if( ( bpozicije[ 0 ] == PROSTO ) || ( PozicijaZaprta( bpozicije[ 0 ] ) == true ) ) { bpozicije[ 0 ] = OdpriPozicijo( OP_BUY, 0, 0 ); }
    sraven = NEVELJAVNO; 
    braven = 0; 
    return( S2 );
  }
  
  // prehod v stanje S4 - Zaključek
  skupniIzkupicek = izkupicekIteracije + VrednostOdprtihPozicij();
  if( skupniIzkupicek >= p )
  {
    if( stonoga == 1 )
    {
      // poiščemo največ vredno SELL pozicijo na nasprotni strani
      najvecVredna = PoisciNajvecVrednoPozicijo( OP_SELL );
      // če na nasprotni strani ni nobene SELL pozicije, potem je največ vredna spozicije[ 0 ]
      if( najvecVredna == 0 ) { najvecVredna = spozicije[ 0 ]; }
    }
    else
    {
      najvecVredna = 0;
    }
    // zapremo vse pozicije razen najvec vredne
    for( i = 0; i < MAX_POZ; i++ ) 
    { 
      // zapremo SELL pozicije
      if( spozicije[ i ] == ZASEDENO ) { spozicije[ i ] = PROSTO; }
      if( ( spozicije[ i ] != PROSTO   ) && ( spozicije[ i ] != najvecVredna ) ) { if( PozicijaZaprta( spozicije[ i ] ) == false ) { ZapriPozicijo( spozicije[ i ] ); } } 
      // zapremo BUY pozicije
      if( bpozicije[ i ] == ZASEDENO ) { bpozicije[ i ] = PROSTO; }    
      if( ( bpozicije[ i ] != PROSTO ) && ( bpozicije[ i ] != najvecVredna ) )   { if( PozicijaZaprta( bpozicije[ i ] ) == false ) { ZapriPozicijo( bpozicije[ i ] ); } }
    }
    if( stonoga == 1 ) { if( PostaviSL( najvecVredna, odmikSL ) == NAPAKA ) { DodajVVrsto( najvecVredna ); } }
    sporocilo = "M5-V"+verzija+":OBVESTILO: Dosežen profitni cilj: " + Symbol() + " iteracija " + IntegerToString( stevilkaIteracije ) + ".";
    braven = NEVELJAVNO; sraven = NEVELJAVNO; SendNotification( sporocilo ); ck = Bid; return( S4 );
  }
  
  // dosežena je naslednja višja raven
  if( Ask <= ceneSravni[ sraven + 1 ] )
  {
    if( ( spozicije[ sraven+1 ] == PROSTO ) || ( PozicijaZaprta( spozicije[ sraven+1 ] ) == true ) ) { spozicije[ sraven + 1 ] = OdpriPozicijo( OP_SELL,  0, sraven + 1 ); }
    sraven++;
    Print( ":[", stevilkaIteracije, "]:", "Nova prodajna raven: ", sraven, " @", DoubleToString( ceneSravni[ sraven ], 5 ) );
  }
  
  // cena pade pod trenutno raven
  if( Ask >= ceneSravni[ sraven ] )
  {
    if( sraven > 0 ) { sraven--; Print( ":[", stevilkaIteracije, "]:", "Nova prodajna raven: ", sraven, " @", DoubleToString( ceneSravni[ sraven ], 5 ) ); }
  }
  
  // če je bil pri eni od pozicij dosežen stop loss takoj popravimo izkupiček iteracije in označimo pozicijo eno raven višje kot prosto
  for( i = 0; i < MAX_POZ; i++ )
  { 
    if( ( bpozicije[ i ] != PROSTO ) && ( bpozicije[ i ] != ZASEDENO ) && ( PozicijaZaprta( bpozicije[ i ] ) == true ) ) 
    { 
      izkupicekIteracije = izkupicekIteracije + VrednostPozicije( bpozicije[ i ] ); bpozicije[ i ] = PROSTO; 
      Print( "Knjižen izkupiček iteracije - BUY" );
    }
    if( ( spozicije[ i ] != PROSTO ) && ( spozicije[ i ] != ZASEDENO ) && ( PozicijaZaprta( spozicije[ i ] ) == true ) ) 
    { 
      izkupicekIteracije = izkupicekIteracije + VrednostPozicije( spozicije[ i ] ); spozicije[ i ] = PROSTO; 
      Print( "Knjižen izkupiček iteracije - SELL" );
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
