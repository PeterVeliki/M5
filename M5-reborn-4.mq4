/*
****************************************************************************************************************************************************************************************
*                                                                                                                                                                                      *
* M5-reborn.mq4                                                                                                                                                                        *
*                                                                                                                                                                                      *
* Copyright Peter Novak ml., M.Sc.                                                                                                                                                     *
****************************************************************************************************************************************************************************************
*/

#property copyright "Peter Novak ml., M.Sc."
#property link      "http://www.marlin.si"



// Vhodni parametri --------------------------------------------------------------------------------------------------------------------------------------------------------------------
extern double L;                       // Velikost pozicij v lotih;
extern double delezProfitniCilj;       // Profitni cilj kot delež ATR(10);
extern double delezMinimalniRazmik;    // Minimalna oddaljenost ostalih pozicij kot delež ATR(10);
extern double delezMinimalnaSveca;     // Minimalna velikost zadnje sveče kot delež ATR(10);
extern int    samodejniPonovniZagon;   // Samodejni ponovni zagon - DA(>0) ali NE(0).
extern int    stevilkaIteracije;       // Številka iteracije. 
extern double odmikSL;                 // Odmik pri postavljanju stop-loss na break-even. Vrednost odmika prištejemo (buy) ali odštejemo (sell) ceni odprtja;
extern double korakMaxIzpostavljenost; // Velikost koraka pri beleženju največje izpostavljenosti.



// Globalne konstante ------------------------------------------------------------------------------------------------------------------------------------------------------------------
#define MAX_POZ     999 // največje možno število odprtih pozicij v eno smer;
#define PROSTO     -1   // oznaka za vsebino polja bpozicije / spozicije;
#define USPEH      -4   // oznaka za povratno vrednost pri uspešno izvedenem klicu funkcije;
#define NAPAKA     -5   // oznaka za povratno vrednost pri neuspešno izvedenem klicu funkcije;
#define S0          1   // oznaka za stanje S0 - Čakanje na zagon;
#define S1          2   // oznaka za stanje S1 - Iteracija v teku;
#define S2          3   // oznaka za stanje S2 - Zaključek;



// Globalne spremenljivke --------------------------------------------------------------------------------------------------------------------------------------------------------------
int    bpozicije [MAX_POZ];     // Enolične oznake vseh odprtih nakupnih pozicij;
int    spozicije [MAX_POZ];     // Enolične oznake vseh odprtih prodajnih pozicij;
int    kbpozicije;              // Kazalec na naslednje prosto mesto v polju bpozicije;
int    kspozicije;              // Kazalec na naslednje prosto mesto v polju spozicije;
int    braven;                  // Trenutna raven na nakupni strani;
int    sraven;                  // Trenutna raven na prodajni strani;
int    danZagona;               // Dan zagona algoritma;
double ceneBravni[MAX_POZ];     // Cene ravni v smeri nakupa;
double ceneSravni[MAX_POZ];     // Cene ravni v smeri prodaje;
double ceneBpozicije[MAX_POZ];  // Cena odprtja istoležne pozicije v polju bpozicije;
double ceneSpozicije[MAX_POZ];  // Cena odprtja istoležne pozicije v polju spozicije;
double izkupicekIteracije;      // Izkupiček trenutne iteracije algoritma (izkupiček odprtih in zaprtih pozicij);
double izkupicekOdprtihPozicij; // Izkupiček samo odprtih pozicij;
double izkupicekZaprtihPozicij; // Izkupiček samo zaprtih pozicij;
double maxIzpostavljenost;      // Največja izguba algoritma (minimum od izkupickaIteracije);
double profitniCilj;            // Profitni cilj - v točkah;
double minimalniRazmik;         // Minimalna oddaljenost ostalih pozicij;
double minimalnaSveca;          // Minimalna velikost zadnje sveče;
int    stanje;                  // Trenutno stanje algoritma;
int    verzija = 4;             // Trenutna verzija algoritma;



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
  (-) začnemo novo iteracijo algoritma, s podano številko iteracije 
(o) Zaloga vrednosti: USPEH, NAPAKA
(o) Vhodni parametri: /
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
int init()
{
   IzpisiPozdravnoSporocilo();
   PonastaviVrednostiPodatkovnihStruktur();
   if(VpisiPozicije(stevilkaIteracije)==FALSE) // iteracija s podano številko ne obstaja
   {
      stanje=S0;
      Print("M5R-V", verzija, ":[", stevilkaIteracije, "]:", ":init:Podana iteracija ne obstaja, odprta nova iteracija št. ", stevilkaIteracije); 
      Print("M5R-V", verzija, ":[", stevilkaIteracije, "]:", ":init:Profitni cilj: ", DoubleToString(profitniCilj, 5)); 
      Print("M5R-V", verzija, ":[", stevilkaIteracije, "]:", ":init:Minimalni razmik: ", DoubleToString(minimalniRazmik, 5));
      Print("M5R-V", verzija, ":[", stevilkaIteracije, "]:", ":init:Minimalna sveca: ", DoubleToString(minimalnaSveca, 5)); 
   }
   else
   {
      stanje=S1;
      OsveziCeneRavni(Ask);
      Print("M5R-V", verzija, ":[", stevilkaIteracije, "]:", ":init:Podana iteracija št. ", stevilkaIteracije, " uspešno prebrana."); 
      Print("M5R-V", verzija, ":[", stevilkaIteracije, "]:", ":init:Profitni cilj: ", DoubleToString(profitniCilj, 5)); 
      Print("M5R-V", verzija, ":[", stevilkaIteracije, "]:", ":init:Minimalni razmik: ", DoubleToString(minimalniRazmik, 5));
      Print("M5R-V", verzija, ":[", stevilkaIteracije, "]:", ":init:Minimalna sveca: ", DoubleToString(minimalnaSveca, 5)); 
   }
   
   return( USPEH );    
} // init



/*--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
FUNKCIJA: start  
---------------
(o) Funkcionalnost: Glavna funkcija, ki upravlja celoten algoritem - sistem jo pokliče ob vsakem ticku. 
(o) Zaloga vrednosti: USPEH (funkcija vedno uspe)
(o) Vhodni parametri: / (uporablja samo globalne spremenljivke)
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
int start()
{
   int trenutnoStanje; 
   
   // zabeležimo za ugotavljanje spremembe stanja
   trenutnoStanje=stanje;
   
   // izračunamo novo stanje
   switch(stanje)
   {
      case S0: stanje = S0CakanjeNaZagon();  break;
      case S1: stanje = S1IteracijaPoteka(); break;
      case S2: stanje = S2Zakljucek();       break;
      default: Print("M5R-V", verzija, ":[", stevilkaIteracije, "]:", ":start:OPOZORILO: Stanje ", stanje, " ni veljavno stanje - preveri pravilnost delovanja algoritma." );
   }

   // če je prišlo do prehoda med stanji izpišemo obvestilo
   if(trenutnoStanje!=stanje) 
   {
      Print("M5R-V", verzija, ":[", stevilkaIteracije, "]:","Prehod: ", ImeStanja(trenutnoStanje)," ===========>>>>> ", ImeStanja(stanje));
   }

   // če se je poslabšala izpostavljenost, to zabeležimo
   if(maxIzpostavljenost>izkupicekIteracije+korakMaxIzpostavljenost) 
   { 
      maxIzpostavljenost=izkupicekIteracije; 
      Print("M5R-V", verzija, ":[", stevilkaIteracije, "]:","Nova največja izpostavljenost: ", DoubleToString(maxIzpostavljenost, 5)); 
   }

   // osveževanje ključnih kazalnikov delovanja algoritma na zaslonu
   Comment("Številka iteracije: ",        stevilkaIteracije,                          " \n",
           "Izkupiček iteracije: ",       DoubleToString(izkupicekIteracije, 5),      " \n",
           "Izkupiček odprtih pozicij: ", DoubleToString(izkupicekOdprtihPozicij, 5), " \n",
           "Izkupiček zaprtih pozicij: ", DoubleToString(izkupicekZaprtihPozicij, 5), " \n",
           "Največja izpostavljenost: ",  DoubleToString(maxIzpostavljenost, 5),      " \n",
           "ATR: ",                       DoubleToString(iATR(NULL, 0, 10, 0), 5),    " \n",
           "Minimalna razdalja ",         DoubleToString(minimalniRazmik, 5),         " \n",
           "Minimalna velikost sveče ",   DoubleToString(minimalnaSveca, 5),          " \n",
           "Profitni cilj ",              DoubleToString(profitniCilj, 5) 
          );
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
FUNKCIJA: DodajVSeznamPozicij( int vrsta, int id )
-------------------------------------
(o) Funkcionalnost: v seznam nakupnih pozicij (bpozicije) ali v seznam prodajnih pozicij (spozicije) doda podano pozicijo.  
(o) Zaloga vrednosti:
  (-) USPEH: pozicija je bila dodana v vrsto;
  (-) NAPAKA: pri dodajanju pozicije je prišlo do napake.
(o) Vhodni parametri: 
   (-) vrsta: OP_BUY (dodajanje v polje bpozicije) ali OP_SELL (dodajanje v polje spozicije);
   (-) id: oznaka pozicije. 
(o) Uporabljene globalne spremenljivke:
  (-) kbpozicije: kazalec na naslednje prosto mesto v seznamu bpozicije;
  (-) kspozicije: kazalec na naslednje prosto mesto v seznamu spozicije.
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
int DodajVSeznamPozicij(int vrsta, int id)
{
   if(vrsta==OP_BUY)
   {
      // dodajanje pozicije v seznam bpozicije
      bpozicije[kbpozicije]=id;
      kbpozicije++;
      Print("M5R-V", verzija,":[",stevilkaIteracije,"]:",":DodajVSeznamPozicij: Nakupna pozicija ", Symbol(),": ", id," dodana med nakupne pozicije.");
      return( USPEH );
   }
   else
   {
      spozicije[kspozicije]=id;
      kspozicije++;
      Print("M5R-V", verzija,":[",stevilkaIteracije,"]:",":DodajVSeznamPozicij: Prodajna pozicija ", Symbol(),": ", id," dodana med prodajne pozicije.");
      return( NAPAKA );
   }
} // DodajVSeznamPozicij



/*--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
FUNKCIJA: ImeStanja( int KodaStanja )
-------------------------------------
(o) Funkcionalnost: Na podlagi numerične kode stanja, vrne opis stanja.  
(o) Zaloga vrednosti: imena stanj
(o) Vhodni parametri: KodaStanja: enolična oznaka stanja. 
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
string ImeStanja(int KodaStanja)
{
   switch(KodaStanja)
   {
      case S0: return( "S0 - ČAKANJE NA ZAGON" );
      case S1: return( "S1 - ITERACIJA POTEKA" );
      case S2: return( "S2 - ZAKLJUČEK"        );
      default: 
         Print ( "M5R-V", verzija, ":[", stevilkaIteracije, "]:", ":ImeStanja:OPOZORILO: Koda stanja ", KodaStanja, " ni prepoznana. Preveri pravilnost delovanja algoritma." );
         return(NAPAKA);      
   }
} // ImeStanja



/*--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
FUNKCIJA: IzpisiPozdravnoSporocilo
----------------------------------
(o) Funkcionalnost: izpiše pozdravno sporočilo, ki vsebuje tudi verzijo algoritma
(o) Zaloga vrednosti: USPEH (funkcija vedno uspe)
(o) Vhodni parametri: /
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
int IzpisiPozdravnoSporocilo()
  {
   Print("****************************************************************************************************************");
   Print("Dober dan. Tukaj M5-reborn, verzija ",verzija, "iteracija ", stevilkaIteracije,".");
   Print("****************************************************************************************************************");
   return( USPEH );
  } // IzpisiPozdravnoSporocilo



/*--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
FUNKCIJA: IzpolnjenPogojZaPonovniZagon
--------------------------------------
(o) Funkcionalnost: izračuna ali je izpolnjen pogoj za ponovni zagon.
(o) Zaloga vrednosti: 
  (-) true: da
  (-) false: ne
(o) Vhodni parametri: /
  (-) uporablja globalne spremenljivke
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
bool IzpolnjenPogojZaPonovniZagon()
{
   if( samodejniPonovniZagon > 0) 
   { 
      return( true ); 
   } 
   else 
   { 
      return( false ); 
   }
} // IzpolnjenPogojZaPonovniZagon



/*--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
FUNKCIJA: NapocilJeNovDan()
---------------------------
(o) Funkcionalnost: preveri ali je napo;il nov dan. 
(o) Zaloga vrednosti: 
  (-) true: da
  (-) false: ne
(o) Vhodni parametri: /
  (-) uporablja globalno spremenljivko danZagona
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
bool NapocilJeNovDan()
{
   int trenutniDan;
   
   trenutniDan=TimeDayOfYear(TimeCurrent());
   if(trenutniDan!=danZagona)
   {
      danZagona=trenutniDan;
      return(TRUE);
   }
   else
   {
      return(FALSE);
   }
} // NapocilJeNovDan



/*--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
FUNKCIJA: ObmocjeProsto(double cena, int smer)
----------------------------------------------
(o) Funkcionalnost: izračuna ali je območje okrog podane cene prosto za odpiranje nove pozicije v podani smeri. Potrebno je upoštevati samo ODPRTE pozicije.
(o) Zaloga vrednosti: 
  (-) true: da
  (-) false: ne
(o) Vhodni parametri: cena
  (-) uporablja globalno spremenljivko minimalniRazmik
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
bool ObmocjeProsto(double cena, int smer)
{
   bool rezultat;
   int  i;
   
   rezultat=TRUE;
   switch(smer)
   {
      case OP_BUY:
         for(i=0; i<kbpozicije;i++)
         {
            // če je v območju minimalnega razmika že odprta pozicija, potem vrnemo FALSE
            if((PozicijaZaprta(bpozicije[i])==FALSE)&&(MathAbs(ceneBpozicije[i]-cena)<minimalniRazmik))
            {
               rezultat=FALSE;
            }
         }
         return(rezultat);
      case OP_SELL:
         for(i=0; i<kspozicije;i++)
         {
            // če je v območju minimalnega razmika že odprta pozicija, potem vrnemo FALSE
            if((PozicijaZaprta(spozicije[i])==FALSE)&&(MathAbs(ceneSpozicije[i]-cena)<minimalniRazmik))
            {
               rezultat=FALSE;
            }
         }
         return(rezultat);
      default:
         return(FALSE);
   }
} // ObmocjeProsto



/*--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
FUNKCIJA: OdpriPozicijo( int Smer, double sl, double tp )
---------------------------------------------------------
(o) Funkcionalnost: Odpre pozicijo po trenutni tržni ceni v podani Smeri in nastavi stop loss ter take profit na podano ceno.
(o) Zaloga vrednosti: ID odprte pozicije;
(o) Vhodni parametri:
   (-) Smer: OP_BUY ali OP_SELL;
   (-) sl: cena za stop loss;
   (-) tp: cena za take profit.
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
int OdpriPozicijo(int Smer,double sl, double tp)
{
   int rezultat;    // spremenljivka, ki hrani rezultat odpiranja pozicije
   string komentar; // spremenljivka, ki hrani komentar za pozicijo

   komentar=StringConcatenate("M5RV", verzija, "-", stevilkaIteracije);

   // pozicijo odpiramo v zanki - poskušamo dokler nam ne uspe
   do
   {
      if( Smer == OP_BUY ) 
      { 
         rezultat = OrderSend( Symbol(), OP_BUY,  L, Ask, 0, sl, tp, komentar, stevilkaIteracije, 0, Green ); 
      }
      else
      { 
         rezultat = OrderSend( Symbol(), OP_SELL, L, Bid, 0, sl, tp, komentar, stevilkaIteracije, 0, Red   ); 
      }
      if(rezultat==-1)
      {
         Print("M5R-V",verzija,":[",stevilkaIteracije,"]:",":OdpriPozicijo:NAPAKA: neuspešno odpiranje pozicije. Ponoven poskus čez 30s...");
         Sleep(30000);
         RefreshRates();
      }
   }
   while(rezultat==-1);
   return(rezultat);
} // OdpriPozicijo



/*--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
FUNKCIJA: OsveziCeneRavni(double c )
---------------------------
(o) Funkcionalnost: Nastavi cene ravni v poljih ceneBravni in ceneSravni, glede na podano začetno ceno
(o) Zaloga vrednosti: USPEH (vedno uspe)
(o) Vhodni parametri: začetna cena
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
int OsveziCeneRavni(double c)
{
   double r; // hrani razdaljo med ravnemi, da ne kličemo tolikokrat funkcije iATR
   
   r=iATR(NULL, 0, 10, 0)*0.5;
   
   // izračunamo ceni začetnih dveh ravni
   ceneBravni[0]=c+r; 
   ceneSravni[0]=c-r; 
   Print("M5R-V", verzija, ":[", stevilkaIteracije, "]:", "Nakupna raven 0: ",  DoubleToString(ceneBravni[0], 5));
   Print("M5R-V", verzija, ":[", stevilkaIteracije, "]:", "Prodajna raven 0: ", DoubleToString(ceneSravni[0], 5));
   
   // izračunamo še cene vseh ostalih ravni
   for(int i=1; i<MAX_POZ; i++) 
   { 
      ceneBravni[i]=ceneBravni[i-1]+r; 
      ceneSravni[i]=ceneSravni[i-1]-r; 
   }
   
   return( USPEH );
  } // OsveziCeneRavni



/*--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
FUNKCIJA: PonastaviVrednostiPodatkovnihStruktur
-----------------------------------------------
(o) Funkcionalnost: funkcija nastavi vrednosti vseh globalnih spremenljivk na začetne vrednosti:
   (-) nastavi cene v poljih ceneBpozicije in ceneSpozicije na 0;
   (-) nastavi vrednosti vseh elementov polja bpozicije na PROSTO;
   (-) nastavi vrednosti vseh elementov polja spozicije na PROSTO;
   (-) nastavi vrednost kazalcev na proste pozicije v poljih bpozicije in spozicije na začetek;
   (-) nastavi vrednost trenutnih ravni na 0;
   (-) nastavi vrednost spremenljivk za spremljanje izkupička iteracije na 0.
(o) Zaloga vrednosti: 
   (-) USPEH: ponastavljanje uspešno;
   (-) NAPAKA: ponastavljanje ni bilo uspešno.
(o) Vhodni parametri: / (uporablja samo globalne spremenljivke).
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
int PonastaviVrednostiPodatkovnihStruktur()
{
   int i;
   
   for(i=0;i<MAX_POZ;i++) 
   { 
      bpozicije[i]=PROSTO; 
      spozicije[i]=PROSTO; 
      ceneBpozicije[i]=0;
      ceneSpozicije[i]=0;
      ceneBravni[i]=0;
      ceneSravni[i]=0;
   }
   
   kbpozicije             =0;
   kspozicije             =0;
   braven                 =0;
   sraven                 =0;
   izkupicekIteracije     =0;
   izkupicekOdprtihPozicij=0;
   izkupicekZaprtihPozicij=0;
   profitniCilj           =delezProfitniCilj*iATR(NULL, 0, 10, 0);
   minimalniRazmik        =delezMinimalniRazmik*iATR(NULL, 0, 10, 0);
   minimalnaSveca         =delezMinimalnaSveca*iATR(NULL, 0, 10, 0);
   danZagona=TimeDayOfYear(TimeCurrent());
   
   return( USPEH );
} // PonastaviVrednostiPodatkovnihStruktur



/*--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
FUNKCIJA: PostaviSL(int id, double odmik)
---------------------------------------
(o) Funkcionalnost: Funkcija poziciji z id-jem id postavi stop loss r točk od vstopne cene:
   (-) če gre za nakupno pozicijo, potem se odmik r PRIŠTEJE k ceni odprtja. Ko je enkrat stop loss postavljen nad ceno odprtja, ga ni več mogoče postaviti pod ceno odprtja, tudi če 
       podamo negativen r;
   (-) če gre za prodajno pozicijo, potem se odmik r ODŠTEJE od cene odprtja. Ko je enkrat stop loss postavljen pod ceno odprtja, ga ni več mogoče postaviti nad ceno odprtja, tudi če 
       podamo negativen r.
(o) Zaloga vrednosti:
   (-) USPEH: ponastavljanje uspešno;
   (-) NAPAKA: ponastavljanje ni bilo uspešno;
(o) Vhodni parametri:
   (-) id: oznaka pozicije;
   (-) odmik: odmik.
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
int PostaviSL(int id, double odmik)
  {
   double ciljniSL;
   bool   modifyRezultat;
   int    selectRezultat;

   selectRezultat=OrderSelect(id,SELECT_BY_TICKET);
   if(selectRezultat==false)
   {
      Print("M5R-V", verzija, ":[", stevilkaIteracije, "]:",  ":PostaviSL:NAPAKA: Pozicije ", id, " ni bilo mogoče najti. Preveri pravilnost delovanja algoritma." ); return( NAPAKA );
   }

   if(OrderType()==OP_BUY) 
   { 
      if(OrderStopLoss()==OrderOpenPrice()+odmik) 
      { 
         return(USPEH); 
      } 
      else 
      { 
         ciljniSL=OrderOpenPrice()+odmik; 
      } 
   }
   else // OrderType()==OP_SELL                    
   { 
      if(OrderStopLoss()==OrderOpenPrice()-odmik) 
      { 
         return(USPEH); 
      } 
      else 
      { 
         ciljniSL=OrderOpenPrice()-odmik; 
      } 
   }

   modifyRezultat=OrderModify(id, OrderOpenPrice(), ciljniSL, OrderTakeProfit(), 0, clrNONE);
   if(modifyRezultat==false)
   {
      Print("M5R-V", verzija, ":[", stevilkaIteracije, "]:", ":PostaviSL:OPOZORILO: Pozicije ", id, " ni bilo mogoče ponastaviti SL. Koda napake: ", GetLastError());
      Print("M5R-V", verzija, ":[",stevilkaIteracije, "]:" , ":PostaviSL:Obstoječi SL = ", DoubleToString(OrderStopLoss(), 5), " Ciljni SL = ", DoubleToString(ciljniSL,5));
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
bool PozicijaZaprta(int id)
  {
   int rezultat;

   rezultat=OrderSelect(id, SELECT_BY_TICKET);
   if(rezultat==false) 
   { 
      Print( "M5R-V", verzija, ":[", stevilkaIteracije, "]:", ":PozicijaZaprta:OPOZORILO: Pozicije ", id, " ni bilo mogoče najti. Preveri pravilnost delovanja algoritma." ); 
      return( true );
   }
   if(OrderCloseTime()==0) 
   { 
      return(false);
   }
   else
   { 
      return(true);  
   }
} // PozicijaZaprta



/*--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
FUNKCIJA: PreveriSLPozicij()
----------------------------
(o) Funkcionalnost: Preveri ali je dosežen pogoj za postavitev SL na BE razdaljo in ponastavi SL pozicijam.
(o) Zaloga vrednosti: USPEH
(o) Vhodni parametri: uporablja globalne spremenljivke
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
int PreveriSLPozicij()
{
   int i;
   int rezultat;
   double atr;
   
   atr=iATR(NULL, 0, 10, 0);
   
   // Preverimo BUY pozicije
   for(i=0;i<kbpozicije;i++)
   {
      rezultat=OrderSelect(bpozicije[i], SELECT_BY_TICKET);
      if(rezultat==false) 
      { 
         Print( "M5R-V", verzija, ":[", stevilkaIteracije, "]:", ":PreveriSLPozicij:OPOZORILO: Pozicije ", bpozicije[i], " ni bilo mogoče najti. Preveri pravilnost delovanja algoritma." ); 
      }
      if((PozicijaZaprta(bpozicije[i])==FALSE)&&(OrderStopLoss()==0))
      {
         if(Bid-OrderOpenPrice()>atr)
         {
            PostaviSL(bpozicije[i], odmikSL);
            Print( "M5R-V", verzija, ":[", stevilkaIteracije, "]:", ":PreveriSLPozicij:INFO: Nakupni poziciji ", bpozicije[i], " je bil nastavljen SL na BE odmik." ); 
         }
      }
   }
   
   // Preverimo SELL pozicije
   for(i=0;i<kspozicije;i++)
   {
      rezultat=OrderSelect(spozicije[i], SELECT_BY_TICKET);
      if(rezultat==false) 
      { 
         Print( "M5R-V", verzija, ":[", stevilkaIteracije, "]:", ":PreveriSLPozicij:OPOZORILO: Pozicije ", spozicije[i], " ni bilo mogoče najti. Preveri pravilnost delovanja algoritma." ); 
      }
      if((PozicijaZaprta(spozicije[i])==FALSE)&&(OrderStopLoss()==0))
      {
         if(OrderOpenPrice()-Ask>atr)
         {
            PostaviSL(spozicije[i], odmikSL);
            Print( "M5R-V", verzija, ":[", stevilkaIteracije, "]:", ":PreveriSLPozicij:INFO: Prodajni poziciji ", spozicije[i], " je bil nastavljen SL na BE odmik." ); 
         }
      }
   }
   return(USPEH);
} // PreveriSLPozicij



/*--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
FUNKCIJA: RazmikUstrezen()
------------------------------------
(o) Funkcionalnost: Izračuna ali je prejšnja sveča dovolj velika (razmik med Open in Close)
(o) Zaloga vrednosti:
   (-) da: TRUE
   (-) ne: FALSE
(o) Vhodni parametri: /
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
bool RazmikUstrezen()
{
   if(MathAbs(Open[1]-Close[1])>=minimalnaSveca)
   {
      return(TRUE);
   }
   else
   {
      return(FALSE);
   }
} // RazmikUstrezen



/*--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
FUNKCIJA: Sveca()
------------------------------------
(o) Funkcionalnost: Vrne podatek ali je zadnja sveča BUY ali SELL.
(o) Zaloga vrednosti:
   (-) buy: OP_BUY
   (-) sell: OP_SELL
(o) Vhodni parametri: /
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
int Sveca()
{
   if(Open[1]>Close[1])
   {
      return(OP_SELL);
   }
   else
   {
      return(OP_BUY);
   }
} // Sveca



/*--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
FUNKCIJA: VpisiPozicije( int st )
----------------------------------
(o) Funkcionalnost: pregleda vse pozicije v terminalu in tiste, ki pripadajo iteraciji st vpiše na ustrezno raven v tabelah bpozicije / spozicije
(o) Zaloga vrednosti: true (iteracija je aktivna), false (iteracija ni aktivna)
(o) Vhodni parametri: st - številka iteracije
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
bool VpisiPozicije( int st )
{
   int    stIteracijeI;     // hramba za številko iteracije
   int    stUkazov;         // stevilo odprtih pozicij v terminalu
   int    stevecbp;         // kazalec na naslednje prosto mesto za vpis v polje bpozicije
   int    stevecsp;         // kazalec na naslednje prosto mesto za vpis v polje spozicije
   int    j;                // števec za premikanje po ukazih v terminalu
   bool   iteracijaAktivna; // če je vsaj ena vpisana pozicija odprta, potem je iteracija aktivna, sicer sklepamo da iteracija ni aktivna

   // najprej bomo prebrali ukaze iz zgodovine
   stUkazov=OrdersHistoryTotal();
   stevecbp=0;
   stevecsp=0;
   
   // za začetek predpostavimo, da iteracija ni aktivna
   iteracijaAktivna=false;
   
   Print("M5R-V", verzija, ":[", stevilkaIteracije, "]:", ":VpisiPozicije:----------Izvajanje pregleda ali podana iteracija ", st, " že obstaja.");
   Print("M5R-V", verzija, ":[", stevilkaIteracije, "]:", ":VpisiPozicije:-------------------- vpisovanje zaprtih pozicij:");
   
   for(j=0; j<stUkazov; j++)
   {
      if(OrderSelect(j, SELECT_BY_POS, MODE_HISTORY)==false) 
      { 
         Print( "M5R-V", verzija, ":[", stevilkaIteracije, "]:", ":VpisiPozicije:OPOZORILO: Napaka pri dostopu do zgodovine pozicij." ); 
      } 
      else                   
      {
         stIteracijeI=OrderMagicNumber();
         if(stIteracijeI==st) 
         { 
            // našli smo pozicijo, ki pripada podani iteraciji
            switch(OrderType())
            {
               case OP_BUY:
                  bpozicije[stevecbp]=OrderTicket();
                  ceneBpozicije[stevecbp]=OrderOpenPrice();
                  Print( "M5R-V", verzija, ":[", stevilkaIteracije, "]:", ":VpisiPozicije:LOG:   - zaprta nakupna pozicija ", OrderTicket(), " uspešno vpisana." ); 
                  stevecbp++;
                  break;
               case OP_SELL:
                  spozicije[stevecsp]=OrderTicket();
                  ceneSpozicije[stevecsp]=OrderOpenPrice();
                  Print( "M5R-V", verzija, ":[", stevilkaIteracije, "]:", ":VpisiPozicije:LOG:   - zaprta prodajna pozicija ", OrderTicket(), " uspešno vpisana." ); 
                  stevecsp++;
                  break;
               default:
                  Print( "M5R-V", verzija, ":[", stevilkaIteracije, "]:", ":VpisiPozicije:NAPAKA: Neprepoznana vrsta pozicije - iteracija označena kot neaktivna." ); 
                  iteracijaAktivna=FALSE;
            }
         }
      } 
   }
   
   // nato preberemo še odprte ukaze
   stUkazov=OrdersTotal();  
   Print("M5R-V", verzija, ":[", stevilkaIteracije, "]:", ":VpisiPozicije:-------------------- vpisovanje odprtih pozicij:");
   for(j=0; j<stUkazov; j++)
   {
      if(OrderSelect(j, SELECT_BY_POS)==false) 
      { 
         Print( "M5R-V", verzija, ":[", stevilkaIteracije, "]:", ":VpisiPozicije:OPOZORILO: Napaka pri dostopu do odprtih pozicij." ); 
      } 
      else                   
      {
         stIteracijeI=OrderMagicNumber();
         if(stIteracijeI==st) 
         { 
            // našli smo pozicijo, ki pripada podani iteraciji
            switch(OrderType())
            {
               case OP_BUY:
                  bpozicije[stevecbp]=OrderTicket();
                  ceneBpozicije[stevecbp]=OrderOpenPrice();
                  Print( "M5R-V", verzija, ":[", stevilkaIteracije, "]:", ":VpisiPozicije:LOG:   - nakupna pozicija ", OrderTicket(), " uspešno vpisana." ); 
                  stevecbp++;
                  if(OrderCloseTime()==0)
                  {
                     iteracijaAktivna=TRUE;
                  }
                  break;
               case OP_SELL:
                  spozicije[stevecsp]=OrderTicket();
                  ceneSpozicije[stevecsp]=OrderOpenPrice();
                  Print( "M5R-V", verzija, ":[", stevilkaIteracije, "]:", ":VpisiPozicije:LOG:   - prodajna pozicija ", OrderTicket(), " uspešno vpisana." ); 
                  stevecsp++;
                  if(OrderCloseTime()==0)
                  {
                     iteracijaAktivna=TRUE;
                  }
                  break;
               default:
                  Print( "M5R-V", verzija, ":[", stevilkaIteracije, "]:", ":VpisiPozicije:NAPAKA: Neprepoznana vrsta pozicije - iteracija označena kot neaktivna." ); 
                  iteracijaAktivna=FALSE;
            }
         }
      }
   }
   kbpozicije=stevecbp;
   kspozicije=stevecsp;
   return(iteracijaAktivna);
} // VpisiPozicije



/*--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
FUNKCIJA: VrednostPozicije(int id)
------------------------------------
(o) Funkcionalnost: Vrne vrednost pozicije z oznako id v točkah
(o) Zaloga vrednosti: vrednost pozicije v točkah
(o) Vhodni parametri: id - oznaka pozicije
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
double VrednostPozicije(int id)
{
   bool rezultat;
   int  vrstaPozicije;

   rezultat=OrderSelect(id,SELECT_BY_TICKET);
   if(rezultat==false) 
   { 
      Print("M5R-V", verzija, ":[", stevilkaIteracije, "]:", ":VrednostPozicije:NAPAKA: Pozicije ", id, " ni bilo mogoče najti. Preveri pravilnost delovanja algoritma."); 
      return(0); 
   }

   vrstaPozicije=OrderType();
   switch(vrstaPozicije)
   {
      case OP_BUY : 
         if(OrderCloseTime()==0) 
         { 
            return(Bid-OrderOpenPrice());
         } 
         else 
         { 
            return(OrderClosePrice()-OrderOpenPrice()); 
         }
      case OP_SELL: 
         if(OrderCloseTime()==0)
         { 
            return(OrderOpenPrice()-Ask); 
         } 
         else 
         { 
            return(OrderOpenPrice()-OrderClosePrice()); 
         }
      default: 
         Print("M5R-V", verzija, ":[", stevilkaIteracije, "]:", ":VrednostPozicije:NAPAKA: Vrsta ukaza ni ne BUY ne SELL. Preveri pravilnost delovanja algoritma." ); 
         return(0);
   }
} // VrednostPozicije



/*--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
FUNKCIJA: OsveziVrednostPozicij()
-----------------------------------
(o) Funkcionalnost: Osveži globalne spremenljivke, ki spremljajo vrednosti pozicij.
(o) Vhodni parametri: /
(o) Zaloga vrednosti: nastavi vrednosti naslednjih globalnih spremenljivk:
   (-) izkupicekIteracije - izkupiček trenutne iteracije algoritma (izkupiček odprtih in zaprtih pozicij);
   (-) izkupicekOdprtihPozicij - izkupiček samo odprtih pozicij;
   (-) izkupicekZaprtihPozicij - izkupiček samo zaprtih pozicij.
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
double OsveziVrednostPozicij()
{
   double vrednost=0;
   double odprteZacasno; 
   double zaprteZacasno;
   int i;
   
   // seštejemo vrednosti vseh pozicij
   zaprteZacasno=0;
   odprteZacasno=0;
   for(i=0; i<kbpozicije; i++)
   {
      if(PozicijaZaprta(bpozicije[i])==TRUE)
      { 
         zaprteZacasno=zaprteZacasno+VrednostPozicije(bpozicije[i]); 
      }
      else
      {
         odprteZacasno=odprteZacasno+VrednostPozicije(bpozicije[i]);
      }
   }
   
   for(i=0; i<kspozicije; i++)
   {
      if(PozicijaZaprta(spozicije[i])==TRUE)
      { 
         zaprteZacasno=zaprteZacasno+VrednostPozicije(spozicije[i]); 
      }
      else
      {
         odprteZacasno=odprteZacasno+VrednostPozicije(spozicije[i]);
      }
   }
   
   // ponastavimo globalne spremenljivke
   izkupicekIteracije     =zaprteZacasno+odprteZacasno;
   izkupicekOdprtihPozicij=odprteZacasno;
   izkupicekZaprtihPozicij=zaprteZacasno;
   return(izkupicekIteracije);
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
bool ZapriPozicijo(int id)
{
   int rezultat;

   rezultat=OrderSelect(id,SELECT_BY_TICKET);
   if(rezultat==false)
   { 
      Print("M5R-V", verzija, ":[", stevilkaIteracije, "]:", ":ZapriPozicijo::NAPAKA: Pozicije ", id, " ni bilo mogoče najti. Preveri pravilnost delovanja algoritma."); 
      return(false); 
   }
   switch(OrderType())
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
Algoritem je bil zagnan, trenutno ni nobenih odprtih pozicij za dano iteracijo. Čakamo na začetek novega dneva.

--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
int S0CakanjeNaZagon()
{
   int smer;
   
   // preverimo ali je napočil nov dan
   if((NapocilJeNovDan()==TRUE)&&(RazmikUstrezen()==TRUE))
   // if(RazmikUstrezen()==TRUE)
   {
      Print("M5R-V", verzija, ":[", stevilkaIteracije, "]:", ":S0CakanjeNaZagon::INFO: Napocil je nov dan: ", danZagona, " in razmik je ustrezen.");  
      smer=Sveca();
      switch(smer)
      {
         case OP_BUY:
            bpozicije[kbpozicije]=OdpriPozicijo(OP_BUY, 0, Ask+profitniCilj);
            ceneBpozicije[kbpozicije]=Ask;
            kbpozicije++;
            OsveziCeneRavni(Ask);
            Print("M5R-V", verzija, ":[", stevilkaIteracije, "]::S0CakanjeNaZagon::INFO: Prejšnja sveča je BUY, odprta pozicija ", bpozicije[kbpozicije-1], ".");
            Print("M5R-V", verzija, ":[", stevilkaIteracije, "]:", ":S0CakanjeNaZagon::INFO: Cena prve BUY ravni je ", DoubleToString(ceneBravni[0], 5), ", cena druge BUY ravni je ", DoubleToString(ceneBravni[1], 5), ".");
            Print("M5R-V", verzija, ":[", stevilkaIteracije, "]:", ":S0CakanjeNaZagon::INFO: Cena prve SELL ravni je ", DoubleToString(ceneSravni[0], 5), ", cena druge SELL ravni je ", DoubleToString(ceneSravni[1], 5), ".");
            return(S1);
            break;
         case OP_SELL:
            spozicije[kspozicije]=OdpriPozicijo(OP_SELL, 0, Bid-profitniCilj);
            ceneSpozicije[kspozicije]=Bid;
            kspozicije++;
            OsveziCeneRavni(Bid);
            Print("M5R-V", verzija, ":[", stevilkaIteracije, "]:", ":S0CakanjeNaZagon::INFO: Prejšnja sveča je SELL, odprta pozicija ", spozicije[kspozicije-1], ".");
            Print("M5R-V", verzija, ":[", stevilkaIteracije, "]:", ":S0CakanjeNaZagon::INFO: Cena prve BUY ravni je ", DoubleToString(ceneBravni[0], 5), ", cena druge BUY ravni je ", DoubleToString(ceneBravni[1], 5), ".");                        Print("M5R-V",verzija,":[",stevilkaIteracije,"]:",":S0CakanjeNaZagon::INFO: Cena prve SELL ravni je ", DoubleToString(ceneSravni[0], 5), ", cena druge SELL ravni je ", DoubleToString(ceneSravni[1], 5), ".");
            Print("M5R-V", verzija, ":[", stevilkaIteracije, "]:", ":S0CakanjeNaZagon::INFO: Cena prve SELL ravni je ", DoubleToString(ceneSravni[0], 5), ", cena druge SELL ravni je ", DoubleToString(ceneSravni[1], 5), ".");
            return(S1);
            break;
         default:
            Print("M5R-V", verzija, ":[", stevilkaIteracije, "]:", ":S0CakanjeNaZagon::NAPAKA: Smer ", smer," ni ne OP_BUY in ne OP_SELL. Preveri pravilnost delovanja algoritma.");  
            return(S0);
      }
   }  
   return( S0 );
} // S0CakanjeNaZagon



/*--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
FUNKCIJA DKA: S1IteracijaPoteka()
Iteracija je v teku.
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
int S1IteracijaPoteka()
{
   int smer;
   int i;
   string sporocilo;
   
   // Preverimo ali je dosežen profitni cilj
   OsveziVrednostPozicij();
   if(izkupicekIteracije>=profitniCilj)
   {
      Print("M5R-V", verzija, ":[", stevilkaIteracije, "]:", ":S1IteracijaPoteka::INFO: Dosežen je profitni cilj, vrednost pozicij je ", DoubleToString(izkupicekIteracije, 5));
      sporocilo="M5R-V"+verzija+"-"+stevilkaIteracije+" Spostovani g. Peter, algoritem M5R vam sporoca, da je bil DOSEZEN profitni cilj iteracije "+stevilkaIteracije+".";
      SendNotification(sporocilo);
      // Zapremo vse odprte nakupne pozicije
      for(i=0; i<kbpozicije; i++) 
      { 
         if(PozicijaZaprta(bpozicije[i])==FALSE)
         {
            ZapriPozicijo(bpozicije[i]);
         }
      }
      // Zapremo vse odprte prodajne pozicije
      for(i=0; i<kspozicije; i++) 
      { 
         if(PozicijaZaprta(spozicije[i])==FALSE)
         {
            ZapriPozicijo(spozicije[i]);
         }
      }
      return(S2);
   }
   
   // Pogoj 1
   if(Bid<=ceneSravni[sraven])
   { 
      sraven++;
      Print("M5R-V", verzija, ":[", stevilkaIteracije, "]:", ":S1IteracijaPoteka::INFO: Dosežena je raven ", sraven-1, " (", DoubleToString(ceneSravni[sraven-1], 5),"), na SELL strani.");
      if(ObmocjeProsto(ceneSravni[sraven-1], OP_SELL)==TRUE)
      {
         spozicije[kspozicije]=OdpriPozicijo(OP_SELL, 0, 0);
         ceneSpozicije[kspozicije]=Bid;
         kspozicije++;
         Print("M5R-V", verzija, ":[", stevilkaIteracije, "]:", ":S1IteracijaPoteka::INFO: Območje je prosto, zato je odprta nova SELL pozicija ", spozicije[kspozicije-1], ".");
      }
      else
      {
         Print("M5R-V", verzija, ":[", stevilkaIteracije, "]:", ":S1IteracijaPoteka::INFO: Območje je ZASEDENO, zato ni bila dodana nova SELL pozicija.");
      }
   }
   
   // Pogoj 2
   if(Ask>=ceneBravni[braven])
   {
      braven++;
      Print("M5R-V", verzija, ":[", stevilkaIteracije, "]:", ":S1IteracijaPoteka::INFO: Dosežena je raven ", braven-1, " (", DoubleToString(ceneBravni[braven-1], 5),"), na BUY strani.");
      if(ObmocjeProsto(ceneBravni[braven-1], OP_BUY)==TRUE)
      {
         bpozicije[kbpozicije]=OdpriPozicijo(OP_BUY, 0, 0);
         ceneBpozicije[kbpozicije]=Ask;
         kbpozicije++;
         Print("M5R-V", verzija, ":[", stevilkaIteracije,"]:", ":S1IteracijaPoteka::INFO: Območje je prosto, zato je odprta nova BUY pozicija ", bpozicije[kbpozicije-1], ".");
      }
      else
      {
         Print("M5R-V", verzija, ":[", stevilkaIteracije,"]:", ":S1IteracijaPoteka::INFO: Območje je ZASEDENO, zato ni bila dodana nova BUY pozicija.");
      }
   }
   
   // Pogoja 3 in 4
   PreveriSLPozicij();
   
   // Pogoja 5 & 6
   if((NapocilJeNovDan()==TRUE)&&(RazmikUstrezen()==TRUE))
   {
      Print("M5R-V", verzija, ":[", stevilkaIteracije, "]:", ":S1IteracijaPoteka::INFO: Napocil je nov dan: ", danZagona," in razmik je ustrezen.");  
      smer=Sveca();
      switch(smer)
      {
         case OP_BUY:
            Print("M5R-V", verzija, ":[", stevilkaIteracije, "]::S1IteracijaPoteka::INFO: Prejšnja sveča je BUY, zato bomo odpirali BUY pozicije.");
            // najprej preverimo če je območje prosto in dodamo dodatno pozicijo brez TP
            if(ObmocjeProsto(Ask, OP_BUY)==TRUE)
            {
               bpozicije[kbpozicije]=OdpriPozicijo(OP_BUY, 0, 0);
               ceneBpozicije[kbpozicije]=Ask;
               Print("M5R-V", verzija, ":[", stevilkaIteracije, "]::S1IteracijaPoteka::INFO: Območje je prosto, zato je odprta prva dodatna BUY pozicija ", bpozicije[kbpozicije], " (brez TP).");
               kbpozicije++;
            }
            else
            {
               Print("M5R-V", verzija, ":[", stevilkaIteracije, "]::S1IteracijaPoteka::INFO: Območje je ZASEDENO, zato dodatna BUY pozicija (brez TP) ni odprta.");
            }
            // nato dodamo še pozicijo s TP, ki ni vezana na to ali je območje prosto ali ne
            bpozicije[kbpozicije]=OdpriPozicijo(OP_BUY, 0, Ask+profitniCilj);
            ceneBpozicije[kbpozicije]=Ask;
            kbpozicije++;
            OsveziCeneRavni(Ask);
            braven=0;
            sraven=0;
            Print("M5R-V", verzija, ":[", stevilkaIteracije, "]::S1IteracijaPoteka::INFO: Odprta dodatna BUY pozicija ", bpozicije[kbpozicije-1], " (s TP).");
            Print("M5R-V", verzija, ":[", stevilkaIteracije, "]:",":S1IteracijaPoteka::INFO: Cena prve BUY ravni je ", DoubleToString(ceneBravni[0], 5), ", cena druge BUY ravni je ", DoubleToString(ceneBravni[1], 5), ".");
            Print("M5R-V", verzija, ":[", stevilkaIteracije, "]:",":S1IteracijaPoteka::INFO: Cena prve SELL ravni je ", DoubleToString(ceneSravni[0], 5), ", cena druge SELL ravni je ", DoubleToString(ceneSravni[1], 5), ".");
            break;
         case OP_SELL:
            Print("M5R-V", verzija, ":[", stevilkaIteracije, "]::S1IteracijaPoteka::INFO: Prejšnja sveča je SELL, zato bomo odpirali SELL pozicije.");
            // najprej preverimo če je območje prosto in dodamo dodatno pozicijo brez TP
            if(ObmocjeProsto(Bid, OP_SELL)==TRUE)
            {
               spozicije[kspozicije]=OdpriPozicijo(OP_SELL, 0, 0);
               ceneSpozicije[kspozicije]=Bid;
               Print("M5R-V", verzija, ":[", stevilkaIteracije, "]::S1IteracijaPoteka::INFO: Območje je prosto, zato je odprta prva dodatna SELL pozicija ", spozicije[kspozicije], " (brez TP).");
               kspozicije++;
            }
            else
            {
               Print("M5R-V", verzija, ":[", stevilkaIteracije, "]::S1IteracijaPoteka::INFO: Območje je ZASEDENO, zato dodatna SELL pozicija (brez TP) ni odprta.");
            }
            spozicije[kspozicije]=OdpriPozicijo(OP_SELL, 0, Bid-profitniCilj);
            ceneSpozicije[kspozicije]=Bid;
            kspozicije++;
            OsveziCeneRavni(Bid);
            braven=0;
            sraven=0;
            Print("M5R-V", verzija, ":[", stevilkaIteracije, "]:", ":S1IteracijaPoteka::INFO: Odprta dodatna SELL pozicija ", spozicije[kspozicije-1], " (s TP).");
            Print("M5R-V", verzija, ":[", stevilkaIteracije, "]:", ":S1IteracijaPoteka::INFO: Cena prve BUY ravni je ", DoubleToString(ceneBravni[0], 5), ", cena druge BUY ravni je ", DoubleToString(ceneBravni[1], 5), ".");
            Print("M5R-V", verzija, ":[", stevilkaIteracije, "]:", ":S1IteracijaPoteka::INFO: Cena prve SELL ravni je ", DoubleToString(ceneSravni[0], 5), ", cena druge SELL ravni je ", DoubleToString(ceneSravni[1], 5), ".");
            
            break;
         default:
            Print("M5R-V", verzija, ":[", stevilkaIteracije, "]:", ":S1IteracijaPoteka::NAPAKA: Smer ", smer," ni ne OP_BUY in ne OP_SELL. Preveri pravilnost delovanja algoritma.");  
      }
   }
   
   return( S1 );
  } // S1IteracijaPoteka



/*--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
FUNKCIJA DKA: S2Zakljucek()
Dosežen je profitni cilj, iteracija je zaključena.
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
int S2Zakljucek()
{
   if(( samodejniPonovniZagon>0)&&(IzpolnjenPogojZaPonovniZagon()==TRUE)) 
   { 
      init(); 
      stevilkaIteracije++;
      return(S0); 
   } 
   else 
   { 
      return(S2); 
   }
} // S2Zakljucek
