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
extern double L=3; // Najvecja dovojena velikost pozicij v lotih;
extern double p=0.00300; // Profitni cilj;
extern double tveganje=5; // Tveganje v odstotkih - uporablja se za izracun velikosti pozicije (privzeto 3%).
extern int    n=0; // Številka iteracije;
extern double stoTock=0.00100; // razdalja sto tock (razlicna za 5 mestne pare in 3 mestne pare)
extern double vrednostStoTock=0.009; // vrednost sto tock v EUR
extern double vstopnaCenaNakup; // Vstopna cena za nakup;
extern double vstopnaCenaProdaja; // Vstopna cena za prodajo;
extern int danZagona=1; // Zaporedna številka dneva v mesecu na katerega je bil algoritem s to številko iteracije prvič pognan.

// Globalne konstante ------------------------------------------------------------------------------------------------------------------------------------------------------------------
#define USPEH      -4 // oznaka za povratno vrednost pri uspešno izvedenem klicu funkcije;
#define NAPAKA     -5 // oznaka za povratno vrednost pri neuspešno izvedenem klicu funkcije;
#define S0          1 // oznaka za stanje S0 - Cakanje na zagon;
#define S1          2 // oznaka za stanje S1 - Zacetno stanje;
#define S2          3 // oznaka za stanje S2 - Nakup;
#define S3          4 // oznaka za stanje S3 - Prodaja;
#define S4          5 // oznaka za stanje S4 - Zakljucek;

// Globalne spremenljivke --------------------------------------------------------------------------------------------------------------------------------------------------------------
int bpozicija; // Enolicna oznaka odprte nakupne pozicije;
int spozicija; // Enolicna oznaka odprte prodajne pozicije;
int stanje; // Trenutno stanje algoritma;
int trenutniDan; // Hrani trenutni dan (zaporedno stevilko dneva v mesecu);
int verzija=7; // Trenutna verzija algoritma;

double maxIzpostavljenost; // Najvecja izguba algoritma (minimum od izkupickaIteracije);
double skupniIzkupicek; // Hrani trenutni skupni izkupicek trenutne iteracije, vkljucno z vrednostjo trenutno odprtih pozicij;

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
(o) Funkcionalnost: Sistem jo poklice ob zaustavitvi. M5 je ne uporablja
(o) Zaloga vrednosti: USPEH (vedno uspe)
(o) Vhodni parametri: /
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/   
int deinit()
{
  return(USPEH);
} // deinit

/*--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
FUNKCIJA: init  
--------------
(o) Funkcionalnost: Sistem jo poklice ob zagonu. V njej izvedemo naslednje:
  (-) izpišemo pozdravno sporocilo
  (-) poklicemo funkcije, ki ponastavijo vse kljucne podatkovne strukture algoritma na zacetne vrednosti
  (-) zacnemo novo iteracijo algoritma, ce je podana številka iteracije 0 ali vzpostavimo stanje algoritma glede na podano številko iteracije
(o) Zaloga vrednosti: USPEH, NAPAKA
(o) Vhodni parametri: /
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
int init()
{
  IzpisiPozdravnoSporocilo();
  PonastaviVrednostiPodatkovnihStruktur();
  
  // Samodejno polnjenje cen vstopa, samo za testiranje. Obvezno zakomentiraj spodnji dve vrstici pred produkcijsko uporabo.
  // vstopnaCenaNakup=iHigh(NULL, PERIOD_D1, 1);
  // vstopnaCenaProdaja=iLow(NULL, PERIOD_D1, 1);
  
  stanje=VzpostaviStanjeAlgoritma(n);
  return(USPEH);
} // init

/*--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
FUNKCIJA: start  
---------------
(o) Funkcionalnost: Glavna funkcija, ki upravlja celoten algoritem - sistem jo poklice ob vsakem ticku.
(o) Zaloga vrednosti: USPEH (funkcija vedno uspe)
(o) Vhodni parametri: /
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
int start()
{
  int trenutnoStanje=stanje; // zabeležimo trenutno stanje, da bomo lahko ugotovili ali je prislo do spremembe stanja
  switch(stanje)
  {
    case S0: stanje=S0CakanjeNaZagon(); break;
    case S1: stanje=S1ZacetnoStanje(); break;
    case S2: stanje=S2Nakup(); break;
    case S3: stanje=S3Prodaja(); break;
    case S4: stanje=S4Zakljucek(); break;
    default: Print( "M5-V", verzija, ":[", n, "]:", ":start:OPOZORILO: Stanje ", stanje, " ni veljavno stanje - preveri pravilnost delovanja algoritma." );
  }
  // ce je prišlo do prehoda med stanji izpišemo obvestilo
  if(trenutnoStanje!=stanje)
  {
    Print(":[", n, "]:", "Prehod: ", ImeStanja( trenutnoStanje ), " ===========>>>>> ", ImeStanja( stanje ) );
  }

  // ce se je poslabšala izpostavljenost, to zabeležimo
  if(maxIzpostavljenost>skupniIzkupicek)
  {
    maxIzpostavljenost=skupniIzkupicek;
    Print(":[", n, "]:", "Nova najvecja izpostavljenost: ", DoubleToString(maxIzpostavljenost, 5));
  }
    
  // osveževanje kljucnih kazalnikov delovanja algoritma na zaslonu
  Comment( "Številka iteracije: ", n,"\n",  
           "Skupni izkupicek:", DoubleToString(skupniIzkupicek, 5), "\n",
           "Najvecja izpostavljenost: ", DoubleToString( maxIzpostavljenost,  5));
  
  return(USPEH);
} // start

/*
****************************************************************************************************************************************************************************************
*                                                                                                                                                                                      *
* POMOŽNE FUNKCIJE                                                                                                                                                                     *
* Urejene po abecednem vrstnem redu                                                                                                                                                    *
****************************************************************************************************************************************************************************************
*/

/*--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
FUNKCIJA: ImeStanja(int KodaStanja)
-------------------------------------
(o) Funkcionalnost: Na podlagi numericne kode stanja, vrne opis stanja.  
(o) Zaloga vrednosti: imena stanj
(o) Vhodni parametri: KodaStanja: enolicna oznaka stanja.
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
string ImeStanja(int KodaStanja)
{
  switch(KodaStanja)
  {
    case S0: return("S0 - CAKANJE NA ZAGON");
    case S1: return("S1 - ZACETNO STANJE");
    case S2: return("S2 - NAKUP");
    case S3: return("S3 - PRODAJA");
    case S4: return("S4 - ZAKLJUCEK");
    default: Print ("M5-V", verzija, ":[", n, "]:", ":ImeStanja:OPOZORILO: Koda stanja ", KodaStanja, " ni prepoznana. Preveri pravilnost delovanja algoritma.");
  }
  return( NAPAKA );
} // ImeStanja

/*--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
FUNKCIJA: IzpisiPozdravnoSporocilo
----------------------------------
(o) Funkcionalnost: izpiše pozdravno sporocilo, ki vsebuje tudi verzijo algoritma
(o) Zaloga vrednosti: USPEH (funkcija vedno uspe)
(o) Vhodni parametri: /
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
int IzpisiPozdravnoSporocilo()
{
  Print("****************************************************************************************************************");
  Print("Dober dan. Tukaj M5, verzija ", verzija, "." );
  Print("****************************************************************************************************************");
  return(USPEH);
} // IzpisiPozdravnoSporocilo

/*--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
FUNKCIJA: IzracunajStopLossCeno(int smer)
-----------------------------------------
(o) Funkcionalnost: izracuna stop loss z uporabo indikatorja Parabolic SAR.
(o) Zaloga vrednosti: cena pri kateri bomo postavili SL.
(o) Vhodni parametri: smer, možni sta dve vrednosti: OP_BUY ali OP_SELL.
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
double IzracunajStopLossCeno(int smer)
{
  int i=0; // zacasna spremenljivka, indeks s katerim se sprehajamo po polju preteklih vrednosti indikatorja iSAR
  double stopLoss; // izracunana vrednost stop loss
  
  switch(smer)
  {
    case OP_BUY:
      // dokler je trenutna vrednost indikatorja nad ceno se pomikamo v preteklost, do prve vrednosti, ki je pod ceno
      while(iSAR(NULL, PERIOD_M15, 0.02, 0.2, i)>=High[i])
      {
        i++;
      }
      // ko smo našli prvo vrednost pod ceno, se ponovno pomikamo v preteklost dokler se indikator spet ne preseli nad ceno. Zadnja vrednost pod ceno je nas stop loss.
      do
      {
        i++;
      }
      while(iSAR(NULL, PERIOD_M15, 0.02, 0.2, i)<=Low[i]);
      stopLoss=iSAR(NULL, PERIOD_M15, 0.02, 0.2, i-1);
      Print("M5-V", verzija, ":[", n, "]:", "IzracunajStopLossCeno:INFO: Nakupna stop loss cena: ", DoubleToString(stopLoss, 5), ".");
      return(stopLoss);
    case OP_SELL:
      // dokler je trenutna vrednost indikatorja pod ceno se pomikamo v preteklost, do prve vrednosti, ki je nad ceno
      while(iSAR(NULL, PERIOD_M15, 0.02, 0.2, i)<=Low[i])
      {
        i++;
      }
      // ko smo našli prvo vrednost nad ceno, se ponovno pomikamo v preteklost dokler se indikator spet ne preseli pod ceno. Zadnja vrednost nad ceno je nas stop loss.
      do
      {
        i++;
      }
      while(iSAR(NULL, PERIOD_M15, 0.02, 0.2, i)>=High[i]);
      stopLoss=iSAR(NULL, PERIOD_M15, 0.02, 0.2, i-1);
      Print("M5-V", verzija, ":[", n, "]:", "IzracunajStopLossCeno:INFO: Prodajna stop loss cena: ", DoubleToString(stopLoss, 5), ".");
      return(stopLoss);
    default:
      Print("M5-V", verzija, ":[", n, "]:", "IzracunajStopLossCeno:NAPAKA: Nepricakovana smer - preveri pravilnost delovanja algoritma.");
      return(0);
  }  
} // IzracunajStopLossCeno

/*--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
FUNKCIJA: IzracunajVelikostPozicije(double tveganje, double razdalja)
---------------------------------------------------------------------
(o) Funkcionalnost: glede na stanje na racunu in podano tveganje v odstotkih izracuna velikost pozicije
(o) Zaloga vrednosti: velikost pozicije
(o) Vhodni parametri:
(-) tveganje: tveganje izrazeno v odstotku stanja na racunu v primeru da je dosezen stop loss
(-) razdalja: razdalja med ceno odprtja in stop loss-om v tockah
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
double IzracunajVelikostPozicije(double tveganje, double razdalja)
{
  int k;
  double l;
  double velikost;
  
  k=(razdalja/stoTock)+1;
  l=((tveganje/100)*AccountBalance())/(k*vrednostStoTock);
  Print("M5-V", verzija, ":[", n, "]:", "Vrednost k=", k, ", l=", DoubleToString(l, 2));
  velikost=0.01*MathFloor(l);
  Print("M5-V", verzija, ":[", n, "]:", "Izracunaj velikostPozicije:INFO: Velikost pozicij: ", DoubleToString(velikost, 2));
  
  // ce izracunana velikost presega najvecjo dovoljeno velikost, ki je podana kot parameter algoritma, potem vrnemo najvecjo dovoljeno velikost;
  if(velikost>L)
  {
    Print("M5-V", verzija, ":[", n, "]:", "Izracunaj velikostPozicije:INFO: Izracunana velikost pozicije ", DoubleToString(velikost, 2),
          " presega maksimalno velikost ", DoubleToString(L, 2), ". Uporabljena bo maksimalna velikost.");
    return(L);
  }
  else
  {
    return(velikost);
  }
} // IzracunajVelikostPozicije

/*--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
FUNKCIJA: NovDan()
----------------------------------------------------
(o) Funkcionalnost: vrne true, ce je napocil nov dan in false ce ni.
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
bool NovDan()
{
  if(trenutniDan!=TimeDay(TimeCurrent()))
  {
    trenutniDan=TimeDay(TimeCurrent());
    return(true);
  }
  else
  {
    return(false);
  }
}

/*--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
FUNKCIJA: OdpriPozicijo( int Smer, double sl, int r )
----------------------------------------------------
(o) Funkcionalnost: Odpre pozicijo po trenutni tržni ceni v podani Smeri in nastavi stop loss na podano ceno
(o) Zaloga vrednosti: ID odprte pozicije;
(o) Vhodni parametri:
(-) Smer: OP_BUY ali OP_SELL
(-) sl: cena za stop loss
(-) velikost: velikost pozicije
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
int OdpriPozicijo( int Smer, double sl, double velikost )
{
  int rezultat; // spremenljivka, ki hrani rezultat odpiranja pozicije
  int magicNumber; // spremenljivka, ki hrani magic number pozicije
  string komentar; // spremenljivka, ki hrani komentar za pozicijo
  magicNumber=n;
  komentar=StringConcatenate( "M5V", verzija, "-", n);

  do
  {
    if(Smer==OP_BUY)
    {
      rezultat=OrderSend(Symbol(), OP_BUY, velikost, Ask, 0, sl, 0, komentar, magicNumber, 0, Green);
    }
    else                 
    {
      rezultat=OrderSend(Symbol(), OP_SELL, velikost, Bid, 0, sl, 0, komentar, magicNumber, 0, Red);
    }
    if(rezultat == -1)
    {
      Print( "M5-V", verzija, ":[", n, "]:", ":OdpriPozicijo:NAPAKA: neuspešno odpiranje pozicije. Ponoven poskus cez 30s..." );
      Sleep( 30000 );
      RefreshRates();
    }
  }
  while(rezultat==-1);
  return(rezultat);
} // OdpriPozicijo

/*--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
FUNKCIJA: PonastaviVrednostiPodatkovnihStruktur
-----------------------------------------------
(o) Funkcionalnost: Funkcija nastavi vrednosti vseh globalnih spremenljivk na zacetne vrednosti;
(o) Vhodni parametri: uporablja globalne spremenljivke - parametre algoritma ob zagonu;
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
int PonastaviVrednostiPodatkovnihStruktur()
{
  skupniIzkupicek=0;
  maxIzpostavljenost=0;
  trenutniDan=TimeDay(TimeCurrent());
  return(USPEH);
} // PonastaviVrednostiPodatkovnihStruktur

/*--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
FUNKCIJA: PostaviSL( int id, double cena )
---------------------------------------
(o) Funkcionalnost: Funkcija poziciji z id-jem id postavi stop loss na podano ceno;
(o) Zaloga vrednosti:
(-) USPEH: ponastavljanje uspešno
(-) NAPAKA: ponastavljanje ni bilo uspešno
(o) Vhodni parametri:
(-) id: oznaka pozicije
(-) cena: cena na katero naj se nastavi stop loss
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
int PostaviSL(int id, double cena)
{
  bool modifyRezultat;
  int selectRezultat;

  selectRezultat=OrderSelect(id, SELECT_BY_TICKET);
  if(selectRezultat==false )
  {
    Print("M5-V", verzija, ":[", n, "]:",  ":PostaviSL:NAPAKA: Pozicije ", id, " ni bilo mogoce najti. Preveri pravilnost delovanja algoritma." );
    return(NAPAKA);
  }
  
  // ce je stop loss že nastavljen, potem ne naredimo nic, v nasprotnem primeru ga nastavimo
  if(OrderStopLoss()==cena)
  {
    return(USPEH);
  }
  else
  {
    modifyRezultat=OrderModify(id, OrderOpenPrice(), cena, 0, 0, clrAquamarine);
  }
  
  // ce je pri postavljanju stop loss-a prišlo do napake, izpisemo opozorilo
  if(modifyRezultat==false)
  {
    Print("M5-V", verzija, ":[", n, "]:", ":PostaviSL:OPOZORILO: Pozicije ", id, " ni bilo mogoce ponastaviti SL. Koda napake: ", GetLastError() );
    Print("M5-V", verzija, ":[", n, "]:", ":PostaviSL:Obstojeci stop loss: ", DoubleToString(OrderStopLoss(), 5), ", ciljni stop loss: ", DoubleToString(cena, 5));
    return(NAPAKA);
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
  if( Rezultat         == false ) { Print( "M5-V", verzija, ":[", n, "]:", ":PozicijaZaprta:OPOZORILO: Pozicije ", id, " ni bilo mogoce najti. Preveri pravilnost delovanja algoritma." ); return( true );}
  if( OrderCloseTime() == 0     ) { return( false ); }
  else                            { return( true );  }
} // PozicijaZaprta

/*--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
FUNKCIJA: VrednostPozicije(int id)
------------------------------------
(o) Funkcionalnost: Vrne vrednost pozicije z oznako id v tockah
(o) Zaloga vrednosti: vrednost pozicije v tockah
(o) Vhodni parametri: id - oznaka pozicije
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
double VrednostPozicije( int id )
{
  bool rezultat;
  int  vrstaPozicije;
  
  rezultat = OrderSelect( id, SELECT_BY_TICKET );
  if( rezultat == false ) { Print( "M5-V", verzija, ":[", n, "]:", ":VrednostPozicije:NAPAKA: Pozicije ", id, " ni bilo mogoce najti. Preveri pravilnost delovanja algoritma." ); return( 0 ); }
  vrstaPozicije = OrderType();
  switch( vrstaPozicije )
  {
    case OP_BUY: if( OrderCloseTime() == 0 ) { return( Bid - OrderOpenPrice() ); } else { return( OrderClosePrice() - OrderOpenPrice()  ); }
    case OP_SELL: if( OrderCloseTime() == 0 ) { return( OrderOpenPrice() - Ask ); } else { return(  OrderOpenPrice() - OrderClosePrice() ); }
    default: Print( "M5-V", verzija, ":[", n, "]:", ":VrednostPozicije:NAPAKA: Vrsta ukaza ni ne BUY ne SELL. Preveri pravilnost delovanja algoritma." ); return( 0 );
  }
} // VrednostPozicije

/*--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
FUNKCIJA: VzpostaviStanjeAlgoritma(int stevilkaIteracije)
---------------------------------------------------------
(o) Funkcionalnost: Preveri ali ob zagonu algoritma obstaja kaksna pozicija, ki ustreza trenutni iteraciji:
   (-) ne obstaja: gre za novo iteracijo, algoritem zacne od zacetka v stanju S0 ali S1 (odvisno od tega ali je trenutniDan razlicen od vrednosti danZagona).
   (-) obstaja vsaj ena pozicija, ki ustreza trenutni iteraciji, vendar nobena ni odprta. V tem primeru algoritem zacne v stanju S1.
   (-) obstaja odprta pozicija, ki ustreza trenutni iteraciji. V tem primeru algoritem nadaljuje v stanju S2, ce je pozicija nakupna oziroma S3, ce je pozicija prodajna.
(o) Zaloga vrednosti:
   (-) stanje: S0, S1, S2, S3 ali S4. Stanje S4 vrnemo v primeru, da je prislo pri vzpostavljanju stanja do napake in algoritem raje ustavimo.
(o) Vhodni parametri:
   (-) stevilkaIteracije - stevilka trenutne iteracije
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
int VzpostaviStanjeAlgoritma(int stevilkaIteracije)
{
   int i; // Stevec za premikanje po zgodovini pozicij.
   int j; // Stevec najdenih pozicij.
   int idTrenutnePozicije; // Hrani id (ticket number) trenutne pozicije.
   int steviloOdprtihPozicij; // Hrani stevilo odprtih pozicij in odprtih ukazov (pending orders), ki pa jih M5V6 ne uporablja.
   int steviloZaprtihPozicij; // Hrani število zaprtih pozicij naloženih v zgodovini terminala.
   
   string oznakaTrenutnePozicije; // Hrani opis (comment) trenutne pozicije.
   string oznakaIskanePozicije; // Hrani opis (comment), ki ustreza pozicijam trenutne iteracije.
   
   // Ustvarimo opis pozicij trenutne iteracije.
   oznakaIskanePozicije="M5V"+IntegerToString(verzija)+"-"+IntegerToString(n);
   Print("M5-V", verzija, ":[", n, "]:VzpostaviStanjeAlgoritma:INFO: iscem pozicije z oznako ", oznakaIskanePozicije, ".");
   
   // Preverimo ali obstaja odprta pozicija
   steviloOdprtihPozicij=OrdersTotal();
   for(i=0; i<steviloOdprtihPozicij; i++)
   {
      // V primeru da pride do napake pri dostopu do podatkov odprte pozicije izpisemo samo opozorilo in nadaljujemo.
      if(OrderSelect(i, SELECT_BY_POS)==false)
      {
         Print("M5-V", verzija, ":[", n, "]:VzpostaviStanjeAlgoritma:OPOZORILO: napaka pri dostopu do spiska odprtih pozicij.");
         continue;
      }
      
      // Preverimo ali se oznaka iskane pozicije ujema z oznako trenutne pozicije.
      oznakaTrenutnePozicije=OrderComment();
      if(StringFind(oznakaTrenutnePozicije, oznakaIskanePozicije, 0)>=0)
      {
         idTrenutnePozicije=OrderTicket();
         switch(OrderType())
         {
            case OP_BUY:
               Print("M5-V", verzija, ":[", n, "]:VzpostaviStanjeAlgoritma:INFO: najdena NAKUPNA odprta pozicija ", idTrenutnePozicije, " z oznako ", oznakaTrenutnePozicije, ".");
               bpozicija=idTrenutnePozicije;
               Print("M5-V", verzija, ":[", n, "]:VzpostaviStanjeAlgoritma:INFO: nadaljujem v stanju ", ImeStanja(S2), ".");
               return(S2);
               break;
            case OP_SELL:
               Print("M5-V", verzija, ":[", n, "]:VzpostaviStanjeAlgoritma:INFO: najdena PRODAJNA odprta pozicija ", idTrenutnePozicije, " z oznako ", oznakaTrenutnePozicije, ".");
               spozicija=idTrenutnePozicije;
               Print("M5-V", verzija, ":[", n, "]:VzpostaviStanjeAlgoritma:INFO: nadaljujem v stanju ", ImeStanja(S3), ".");
               return(S3);
               break;
            default:
               Print("M5-V", verzija, ":[", n, "]:VzpostaviStanjeAlgoritma:OPOZORILO: najdena pozicija ", idTrenutnePozicije, " z oznako ", oznakaTrenutnePozicije, 
                     " ni ne nakupna in ne prodajna, zato je ne bomo upostevali.");
         }               
      }
   }
   
   // Preverimo ali obstaja zaprta pozicija
   steviloZaprtihPozicij=OrdersHistoryTotal();	
   j=0;
   for(i=0; i<steviloZaprtihPozicij; i++)	
   {	
      // V primeru da pride do napake pri dostopu do podatkov zgodovine pozicij izpisemo samo opozorilo in nadaljujemo.
      if(OrderSelect(i, SELECT_BY_POS, MODE_HISTORY)==false)	
      { 
         Print( "M5-V", verzija, ":[", stevilkaIteracije, "]:VzpostaviStanjeAlgoritma: napaka pri dostopu do zgodovine pozicij." ); 
         continue; 
      }
      
      // Preverimo ali se oznaka pozicije ujema z oznako trenutne pozicije
      oznakaTrenutnePozicije=OrderComment();
      if(StringFind(oznakaTrenutnePozicije, oznakaIskanePozicije, 0)>=0)
      {
         idTrenutnePozicije=OrderTicket();
         switch(OrderType())
         {
            case OP_BUY:
               Print("M5-V", verzija, ":[", n, "]:VzpostaviStanjeAlgoritma:INFO: najdena ZAPRTA NAKUPNA pozicija ", idTrenutnePozicije, " z oznako ", oznakaTrenutnePozicije, ".");
               j++;
               break;
            case OP_SELL:
               Print("M5-V", verzija, ":[", n, "]:VzpostaviStanjeAlgoritma:INFO: najdena ZAPRTA PRODAJNA pozicija ", idTrenutnePozicije, " z oznako ", oznakaTrenutnePozicije, ".");
               j++;
               break;
            default:
               Print("M5-V", verzija, ":[", n, "]:VzpostaviStanjeAlgoritma:OPOZORILO: najdena ZAPRTA pozicija ", idTrenutnePozicije, " z oznako ", oznakaTrenutnePozicije,
                     " ni ne nakupna in ne prodajna, zato je ne bomo upostevali.");   
         }
      }
   }
   
   // Izpisemo povzetek iskanja zaprtih pozicij
   if(j>0) 
   {
      Print("M5-V", verzija, ":[", n, "]:VzpostaviStanjeAlgoritma:INFO: skupno stevilo najdenih zaprtih pozicij: ", j);
      // Algoritem zazenemo samo v primeru da je trenutna cena znotraj intervala vstopnih cen 
      if((Bid<=vstopnaCenaNakup)&&(Ask>=vstopnaCenaProdaja))
      {
         Print("M5-V", verzija, ":[", n, "]:VzpostaviStanjeAlgoritma:INFO: nadaljujem v stanju ", ImeStanja(S1), ".");
         return(S1);
      }
      else
      {
         Print("M5-V", verzija, ":[", n, "]:VzpostaviStanjeAlgoritma:OPOZORILO: trenutna cena je izven intervala vstopnih cen zato algoritma ni mogoce pognati.");
         Print("M5-V", verzija, ":[", n, "]:VzpostaviStanjeAlgoritma:INFO: nadaljujem v stanju ", ImeStanja(S4), ".");
         return(S4);
      }
   }
   
   // Če smo prišli do sem, ni bilo najdene nobene odprte in nobene zaprte pozicije. Glede na danZagona, nadaljujemo v stanju S0 ali S1, ce je cena znotraj intervala vstopnih cen.
   Print("M5-V", verzija, ":[", n, "]:VzpostaviStanjeAlgoritma:INFO: ni bilo najdenih odprtih ali zaprtih pozicij z oznako ", oznakaIskanePozicije, ".");
   Print("M5-V", verzija, ":[", n, "]:VzpostaviStanjeAlgoritma:INFO: Algoritem je bil zagnan na dan ", danZagona, ", danes je dan ", trenutniDan, "."); 
   if((Bid<=vstopnaCenaNakup)&&(Ask>=vstopnaCenaProdaja))
   {
      if(danZagona==trenutniDan)
      {
         Print("M5-V", verzija, ":[", n, "]:VzpostaviStanjeAlgoritma:INFO: iteracijo nadaljujem v stanju ", ImeStanja(S0), ".");
         return(S0);   
      }
      else
      {      
         Print("M5-V", verzija, ":[", n, "]:VzpostaviStanjeAlgoritma:INFO: iteracijo nadaljujem v stanju ", ImeStanja(S1), ".");
         return(S1);
      }
   }
   else
   {
      Print("M5-V", verzija, ":[", n, "]:VzpostaviStanjeAlgoritma:OPOZORILO: trenutna cena je izven intervala vstopnih cen zato algoritma ni mogoce pognati.");
      Print("M5-V", verzija, ":[", n, "]:VzpostaviStanjeAlgoritma:INFO: nadaljujem v stanju ", ImeStanja(S4), ".");
      return(S4);
   }
} // VzpostaviStanjeAlgoritma

/*--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
FUNKCIJA: ZapriPozicijo( int id )
---------------------------------
(o) Funkcionalnost: Zapre pozicijo z oznako id po trenutni tržni ceni.
(o) Zaloga vrednosti:
(-) true: ce je bilo zapiranje pozicije uspešno;
(-) false: ce zapiranje pozicije ni bilo uspešno;
(o) Vhodni parametri: id - oznaka pozicije.
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
bool ZapriPozicijo( int id )
{
  int Rezultat;

  Rezultat = OrderSelect( id, SELECT_BY_TICKET );
  if( Rezultat == false )
    { Print( "M5-V", verzija, ":[", n, "]:", ":ZapriPozicijo::NAPAKA: Pozicije ", id, " ni bilo mogoce najti. Preveri pravilnost delovanja algoritma." ); return( false ); }
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
* FUNKCIJE DKA                                                                                                                                                                         *
*                                                                                                                                                                                      *
****************************************************************************************************************************************************************************************
*/
/*--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
FUNKCIJA DKA: S0CakanjeNaZagon()
--------------------------------
V to stanje vstopimo takoj po zakljuceni inicializaciji algoritma. V tem stanju cakamo, da se bo zacel nov trgovalni dan.
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
int S0CakanjeNaZagon()
{
  if(NovDan()==true) // ce je nastopil nov dan, potem gremo naprej v zacetno stanje
  {
    return(S1);
  }
  else  // v nasprotnem primeru ostanemo v tem stanju
  {
    return(S0);
  }
} // S0CakanjeNaZagon

/*--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
FUNKCIJA DKA: S1ZacetnoStanje()
-------------------------------
V tem stanju se znajdemo, ko je nastopil nov trgovalni dan in v njem cakamo, da bo dosežena bodisi cena za vstop v smeri nakupa (parameter vstopnaCenaNakup) bodisi cena za vstop
v smeri prodaje (parameter vstopnaCenaProdaja).
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
int S1ZacetnoStanje()
{
  double stopLossCena;
  
  if(Bid>=vstopnaCenaNakup) // ce je presezena cena nakupne ravni, odpremo nakupno pozicijo in gremo v stanje S2
  {
    stopLossCena=IzracunajStopLossCeno(OP_BUY);
    bpozicija=OdpriPozicijo(OP_BUY, stopLossCena, IzracunajVelikostPozicije(tveganje, Ask-stopLossCena));
    return(S2);
  }
  if(Ask<=vstopnaCenaProdaja) // ce je presezena cena prodajne ravni, odpremo prodajno pozicijo in gremo v stanje S3
  {
    stopLossCena=IzracunajStopLossCeno(OP_SELL);
    spozicija=OdpriPozicijo(OP_SELL, stopLossCena, IzracunajVelikostPozicije(tveganje, stopLossCena-Bid));
    return(S3);
  }
  
  // dokler smo znotraj intervala med obema vstopnima cenama, ostajamo v tem stanju
  return(S1);
} // S1ZacetnoStanje

/*--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
FUNKCIJA DKA: S2Nakup()
-----------------------
V tem stanju imamo odprto nakupno pozicijo in cakamo, da bo bodisi dosezen profitni cilj ali pa se bo sprožil stop loss. V prvem primeru gremo v koncno stanje, v drugem primeru pa se
vrnemo nazaj v stanje S1 in cakamo na morebitno novo priložnost za vstop v isti ali v nasprotni smeri.
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
int S2Nakup()
{
  string sporocilo;  // niz za sestavljanje sporocila, ki ga posljemo na terminal ob doseženem profitnem cilju
  double vrednost; // zacasna spremenljivka, ki hrani trenutno vrednost pozicije
  
  // ce je dosezen profitni cilj, zapremo odprto pozicijo in gremo v koncno stanje. Posljemo tudi sporocilo na terminal.
  vrednost=VrednostPozicije(bpozicija);
  if(vrednost>=p)
  {
    ZapriPozicijo(bpozicija);
    skupniIzkupicek=skupniIzkupicek+vrednost;
    sporocilo="M5-V"+verzija+":OBVESTILO: dosežen profitni cilj: "+Symbol()+" iteracija "+IntegerToString(n) + ".";
    Print(sporocilo);
    SendNotification(sporocilo);
    return(S4);
  }
  
  // ce se je sprozil stop loss, potem zabelezimo izkupicek in se vrnemo nazaj v stanje S1
  if(PozicijaZaprta(bpozicija)==true)
  {
    skupniIzkupicek=skupniIzkupicek+vrednost;
    return(S1);
  }
  
  // ce se ni zgodilo nic od zgoraj navedenega, ostanemo v tem stanju
  return(S2);
} // S2Nakup

/*--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
FUNKCIJA DKA: S3Prodaja()
-------------------------
V tem stanju imamo odprto prodajno pozicijo in cakamo, da bo bodisi dosezen profitni cilj ali pa se bo sprožil stop loss. V prvem primeru gremo v koncno stanje, v drugem primeru pa se
vrnemo nazaj v stanje S1 in cakamo na morebitno novo priložnost za vstop v isti ali v nasprotni smeri.
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
int S3Prodaja()
{
  string sporocilo;  // niz za sestavljanje sporocila, ki ga posljemo na terminal ob doseženem profitnem cilju
  double vrednost; // zacasna spremenljivka, ki hrani trenutno vrednost pozicije
  // ce je dosezen profitni cilj, zapremo odprto pozicijo in gremo v koncno stanje. Posljemo tudi sporocilo na terminal.
  vrednost=VrednostPozicije(spozicija);
  if(vrednost>=p)
  {
    ZapriPozicijo(spozicija);
    skupniIzkupicek=skupniIzkupicek+vrednost;
    sporocilo="M5-V"+verzija+":OBVESTILO: dosežen profitni cilj: "+Symbol()+" iteracija "+IntegerToString(n) + ".";
    Print(sporocilo);
    SendNotification(sporocilo);
    return(S4);
  }
  
  // ce se je sprozil stop loss, potem zabelezimo izkupicek in se vrnemo nazaj v stanje S1
  if(PozicijaZaprta(spozicija)==true)
  {
    skupniIzkupicek=skupniIzkupicek+vrednost;
    return(S1);
  }
  
  // ce se ni zgodilo nic od zgoraj navedenega, ostanemo v tem stanju
  return(S3);
} // S3Prodaja

/*--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
FUNKCIJA DKA: S4Zakljucek()
V tem stanju se znajdemo, ko je bil dosežen profitni cilj. To je koncno stanje.
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
int S4Zakljucek()
{
  return(S4);
} // S4Zakljucek
