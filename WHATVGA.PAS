
uses dos,crt,supervga;


procedure setpix(x,y:word;col:longint);
const
  msk:array[0..7] of byte=(128,64,32,16,8,4,2,1);
  plane :array[0..1] of byte=(5,10);
  plane4:array[0..3] of byte=(1,2,4,8);
  mscga4:array[0..3] of byte=($3f,$cf,$f3,$fc);
  shcga4:array[0..3] of byte=(6,4,2,0);
var l:longint;
    m,z:word;
begin
  case memmode of
   _cga2:begin
           z:=(y shr 1)*bytes+(x shr 3);
           if odd(y) then inc(z,8192);
           mem[$b800:z]:=(mem[$b800:z] and (255 xor msk[x and 7]))
                         or ((col and 1) shl (7-(x and 7)));
         end;
   _cga4:begin
           z:=(y shr 1)*bytes+(x shr 2);
           if odd(y) then inc(z,8192);
           mem[$b800:z]:=(mem[$b800:z] and mscga4[x and 3])
                         or (col and 3) shl shcga4[x and 3];
         end;
    _pl2:begin
           l:=y*bytes+(x shr 3);
           wrinx($3ce,3,0);
           wrinx($3ce,5,2);
           wrinx($3c4,2,1);
           wrinx($3ce,8,msk[x and 7]);
           setbank(l shr 16);
           z:=mem[vseg:word(l)];
           mem[vseg:word(l)]:=col;
         end;
   _pl2e:begin
           l:=y*128+(x shr 3);
           modinx($3ce,5,3,0);
           wrinx($3c4,2,15);
           wrinx($3ce,0,col*3);
           wrinx($3ce,1,3);
           wrinx($3ce,8,msk[x and 7]);
           z:=mem[vseg:word(l)];
           mem[vseg:word(l)]:=0;
         end;
    _pl4:begin
           l:=y*bytes+(x shr 4);
           wrinx($3ce,3,0);
           wrinx($3ce,5,2);
           wrinx($3c4,2,plane[(x shr 3) and 1]);
           wrinx($3ce,8,msk[x and 7]);
           setbank(l shr 16);
           z:=mem[vseg:word(l)];
           mem[vseg:word(l)]:=col;
         end;
    _pk4:begin
           l:=y*bytes+(x shr 2);
           setbank(l shr 16);
           z:=mem[vseg:word(l)] and mscga4[x and 3];
           mem[vseg:word(l)]:=z or (col shl shcga4[x and 3]);
         end;
   _pl16:begin
           l:=y*bytes+(x shr 3);
           wrinx($3ce,3,0);
           wrinx($3ce,5,2);
           wrinx($3ce,8,msk[x and 7]);
           setbank(l shr 16);
           z:=mem[vseg:word(l)];
           mem[vseg:word(l)]:=col;
         end;
   _pk16:begin
           l:=y*bytes+(x shr 1);
           setbank(l shr 16);
           z:=mem[vseg:word(l)];
           if odd(x) then z:=z and $f+(col shl 4)
                     else z:=z and $f0+col;
           mem[vseg:word(l)]:=z;
         end;
   _p256:begin
           l:=y*bytes+x;
           setbank(l shr 16);
           mem[vseg:word(l)]:=col;
         end;
   _p32k,_p64k:
         begin
           l:=y*bytes+(x shl 1);
           setbank(l shr 16);
           memw[vseg:word(l)]:=col;
         end;
   _p16m:begin
           l:=y*bytes+(x*3);
           z:=word(l);
           m:=l shr 16;
           setbank(m);
           if z<$fffe then move(col,mem[vseg:z],3)
           else begin
             mem[vseg:z]:=lo(col);
             if z=$ffff then setbank(m+1);
             mem[vseg:z+1]:=lo(col shr 8);
             if z=$fffe then setbank(m+1);
             mem[vseg:z+2]:=col shr 16;
           end;
         end;
    else ;
  end;
end;


procedure setvstartxy(x,y:word);
var l:longint;
begin
  l:=0;
  case memmode of
          _pl16:l:=(bytes*y+(x div 8))*4;
          _p256:l:=bytes*y+x;
    _p32k,_p64k:l:=bytes*y+x*2;
          _p16m:l:=bytes*y+x*3;
  end;
  setvstart(l);
end;


function whitecol:longint;
var col:longint;
begin
  case memmode of
    _cga2,_pl2e,
     _pl2:col:=1;
    _cga4,_pk4
    ,_pl4:col:=3;
    _pk16,_pl16,
    _p256:col:=15;
    _p32k:col:=$7fff;
    _p64k:col:=$ffff;
    _p16m:col:=$ffffff;
  else
  end;
  whitecol:=col;
end;


procedure wrtext(x,y:word;txt:string);      {write TXT to pos (X,Y)}
type
  pchar=array[char] of array[0..15] of byte;
var
  p:^pchar;
  c:char;
  i,j,z,b:integer;
  ad,bk:word;
  l,v,col:longint;
begin
  rp.bh:=6;
  vio($1130);
  case memmode of
    _cga2,_pl2e,
     _pl2:col:=1;
    _cga4,_pk4
    ,_pl4:col:=3;
    _pk16,_pl16,
    _p256:col:=15;
    _p32k:col:=$7fff;
    _p64k:col:=$ffff;
    _p16m:col:=$ffffff;
  else
  end;
  p:=ptr(rp.es,rp.bp);
  for z:=1 to length(txt) do
  begin
    c:=txt[z];
    for j:=0 to 15 do
    begin
      b:=p^[c][j];
      for i:=0 to 7 do
      begin
        if (b and 128)<>0 then v:=col else v:=0;
        setpix(x+i,y+j,v);
        b:=b shl 1;
      end;
    end;
    inc(x,8);
  end;
end;


procedure drawtestpattern(nam:string);
                       {Draw Test pattern.}
var s:string;
  l:longint;
  x,y,yst:word;
  white:longint;

  function rgb(r,g,b:word):longint;
  begin
    r:=lo(r);g:=lo(g);b:=lo(b);
    case colbits[memmode] of
       1:rgb:=r and 1;
       2:rgb:=r and 3;
       4:rgb:=r and 15;
       8:rgb:=r;
      15:rgb:=((r shr 3) shl 5+(g shr 3)) shl 5+(b shr 3);
      16:rgb:=((r shr 3) shl 6+(g shr 2)) shl 5+(b shr 3);
      24:rgb:=(longint(r) shl 8+g) shl 8 +b;
    end;
  end;


  procedure wline(stx,sty,ex,ey:integer);
  var x,y,d,mx,my:integer;
     l:longint;
  begin
    if sty>ey then
    begin
      x:=stx;stx:=ex;ex:=x;
      x:=sty;sty:=ey;ey:=x;
    end;
    y:=0;
    mx:=abs(ex-stx);
    my:=ey-sty;
    d:=0;
    repeat
      l:=rgb(y,y,y);
      y:=(y+1) and 255;
      setpix(stx,sty,l);
      if abs(d+mx)<abs(d-my) then
      begin
        inc(sty);
        d:=d+mx;
      end
      else begin
        d:=d-my;
        if ex>stx then inc(stx)
                  else dec(stx);
      end;
    until (stx=ex) and (sty=ey);

  end;

begin

  white:=whitecol;

  wline(50,30,pixels-50,30);
  wline(50,lins-30,pixels-50,lins-30);

  wline(50,30,50,lins-30);
  wline(pixels-50,30,pixels-50,lins-30);
  wline(50,30,pixels-50,lins-30);

  wline(pixels-50,30,50,lins-30);

  if lins>200 then yst:=50 else yst:=10;
  wrtext(10,yst,name+' with '+istr(mm)+' Kbytes.');
  wrtext(10,yst+25,nam);

  for x:=1 to (pixels-10) div 100 do
  begin
    for y:=1 to 10 do
      setpix(x*100,y,white);
    wrtext(x*100+3,1,istr(x));
  end;

  for x:=1 to (lins-10) div 100 do
  begin
    for y:=1 to 10 do
      setpix(y,x*100,white);
    wrtext(1,x*100+2,istr(x));
  end;

  case memmode of
     _pk4,
     _pl4:for x:=0 to 63 do
            for y:=0 to 63 do
              setpix(30+x,yst+y+50,y shr 3);
    _pk16,
    _pl16:for x:=0 to 127 do
            if lins<250 then
              for y:=0 to 63 do
                setpix(30+x,yst+y+50,y shr 2)
            else
              for y:=0 to 127 do
                setpix(30+x,yst+y+50,y shr 3);
    _p256:for x:=0 to 127 do
            if lins<250 then
              for y:=0 to 63 do
                setpix(30+x,yst+50+y,((y shl 2) and 240) +(x shr 3))
            else
              for y:=0 to 127 do
                setpix(30+x,yst+50+y,((y shl 1) and 240)+(x shr 3));

    _p32k,_p64k,_p16m:
          if pixels<600 then
          begin
            for x:=0 to 63 do
            begin
              for y:=0 to 63 do
              begin
                setpix(30+x,100+y,rgb(x*4,y*4,0));
                setpix(110+x,100+y,rgb(x*4,0,y*4));
                setpix(190+x,100+y,rgb(0,x*4,y*4));
              end;
            end;
            for x:=0 to 255 do
              for y:=170 to 179 do
              begin
                setpix(x,y,rgb(x,0,0));
                setpix(x,y+10,rgb(0,x,0));
                setpix(x,y+20,rgb(0,0,x));
              end;
          end
          else begin
            for x:=0 to 127 do
              for y:=0 to 127 do
              begin
                setpix(30+x,120+y,rgb(x*2,y*2,0));
                setpix(200+x,120+y,rgb(x*2,0,y*2));
                setpix(370+x,120+y,rgb(0,x*2,y*2));
              end;
            for x:=0 to 511 do
              for y:=260 to 269 do
              begin
                setpix(x,y,rgb(x shr 1,0,0));
                setpix(x,y+10,rgb(0,x shr 1,0));
                setpix(x,y+20,rgb(0,0,x shr 1));
              end;
          end;

  end;
end;


procedure testvmode;
begin
  drawtestpattern('Mode: '+hex4(curmode)+'h: '+istr(pixels)+'x'+istr(lins)+' '
     +istr(modecols[memmode])+' colors');
  if readkey='' then;

  textmode(3);
end;

procedure wrmono(s:string);
var x:word;
begin
  for x:=1 to length(s) do
    mem[$b000:x+x]:=ord(s[x]);
end;

procedure testscrollmode;
var s:string;
  r13,sclins,scpixs:word;
  x0,y0:integer;
  ch:char;
begin
  sclins:=lins;
  scpixs:=pixels;
  s:='Mode: '+hex4(curmode)+'h: '+istr(pixels)+'x'+istr(lins)+' '+istr(modecols[memmode])+' colors';
  r13:=rdinx(crtc,$13);
  if (r13<128) and ((bytes*lins*planes*5 div 2)<mm*longint(1024)) then
  begin
    wrinx(crtc,$13,r13*2);
    bytes:=bytes*2;
    pixels:=pixels*2;
  end;
  lins:=mm*longint(1024) div (bytes*planes);

  for x0:=0 to (mm div 64)-1 do
  begin
    setbank(x0);
    fillchar(mem[vseg:1],$ffff,0);
    mem[vseg:0]:=0;
  end;

  drawtestpattern(s);
  x0:=0;
  y0:=0;
  repeat
    setvstartxy(x0,y0);
    wrmono(istr(x0)+':'+istr(y0)+'.');
    ch:=readkey;
    if ch=#0 then
      case readkey of
        #72:y0:=y0-16;
        #75:x0:=x0-16;
        #77:x0:=x0+16;
        #80:y0:=y0+16;
        #73:dec(y0);
        #81:inc(y0);
      end;
    if x0<0 then x0:=0;
    if y0<0 then y0:=0;
    if x0>pixels-scpixs then x0:=pixels-scpixs;
    if y0>lins-sclins then y0:=lins-sclins;

  until (ch=#27) or (ch=#13);

  textmode(3);
end;







procedure testvgamodes;           {Test extended modes}
var m:word;
  md:integer;
  c:char;

procedure tmode(m:word);
begin
  memmode:=modetbl[m].memmode;
  pixels :=modetbl[m].xres;
  lins   :=modetbl[m].yres;
  bytes  :=modetbl[m].bytes;
  if setmode(modetbl[m].md) then testvmode;
end;

begin
  textmode($103);
  writeln('Modes:');
  writeln;
  for m:=1 to nomodes do
  begin
    writeln('  '+chr(m+64)+' '+hex4(modetbl[m].md)+'h '+istr(modetbl[m].xres)
           +'x'+istr(modetbl[m].yres)+' '+mdtxt[modetbl[m].memmode]);
  end;
  writeln;

  writeln('  *  All modes');

  writeln;
  c:=upcase(readkey);
  for m:=1 to nomodes do
    if (c='*') or (c=chr(m+64)) then tmode(m);

end;

procedure teststdvgamodes;          {Test standard VGA modes}
var m:word;
  md:integer;
  c:char;

procedure tmode(m:word);
begin
  memmode:=stdmodetbl[m].memmode;
  pixels :=stdmodetbl[m].xres;
  lins   :=stdmodetbl[m].yres;
  bytes  :=stdmodetbl[m].bytes;
  if setmode(stdmodetbl[m].md) then testvmode;
end;

begin
  textmode($103);
  writeln('Modes:');
  writeln;
  for m:=1 to novgamodes do
  begin
    writeln('  '+chr(m+64)+' '+hex4(stdmodetbl[m].md)+'h '+istr(stdmodetbl[m].xres)
           +'x'+istr(stdmodetbl[m].yres)+' '+mdtxt[stdmodetbl[m].memmode]);
  end;
  writeln;
  writeln('  *  All modes');

  writeln;
  c:=upcase(readkey);
  for m:=1 to novgamodes do
    if (c='*') or (c=chr(m+64)) then tmode(m);

end;


procedure testscrollmodes;           {Test scrolling}
var
  m:word;
  c:char;

procedure tmode(m:word);
begin
  memmode:=modetbl[m].memmode;
  pixels :=modetbl[m].xres;
  lins   :=modetbl[m].yres;
  bytes  :=modetbl[m].bytes;
  if setmode(modetbl[m].md) then testscrollmode;
end;

begin
  textmode($103);
  writeln('Modes:');
  writeln;
  for m:=1 to nomodes do
  begin
    writeln('  '+chr(m+64)+' '+hex4(modetbl[m].md)+'h '+istr(modetbl[m].xres)
           +'x'+istr(modetbl[m].yres)+' '+mdtxt[modetbl[m].memmode]);
  end;
  writeln;

  writeln('  *  All modes');

  writeln;
  c:=upcase(readkey);
  for m:=1 to nomodes do
    if (c='*') or (c=chr(m+64)) then tmode(m);

end;

procedure searchformodes;      {Run through all possible modes
                                and try to id any new ones}
type
  regblk=record
           base:word;
           nbr:word;
           x:array[0..255] of byte;
         end;
var
  md,m,bseg,hig,wid,x,y,oldbytes,wordadr:word;
  c:char;
  ofil:text;
  attregs:array[0..31] of byte;
  seqregs,grcregs,crtcregs,xxregs:regblk;
  stdregs:array[$3c0..$3df] of byte;
  l:longint;
  s:string;


procedure dumprg(base:word;var rg:regblk);
var six,ix:word;
begin
  rg.base:=base;
  six:=inp(base);
  outp(base,255);
  ix:=inp(base);
  if ix>127 then rg.nbr:=255
  else if ix>63 then rg.nbr:=127
  else if ix>31 then rg.nbr:=63
  else if ix>15 then rg.nbr:=31
  else if ix>7 then rg.nbr:=15
  else rg.nbr:=7;
  for ix:=0 to rg.nbr do
    rg.x[ix]:=rdinx(base,ix);
  outp(base,six);
end;

procedure wrregs(var f:text;var rg:regblk);
var x:word;
begin
  write(f,hex4(rg.base)+':');
  for x:=0 to rg.nbr do
  begin
    if (x mod 25=0) and (x>0) then
      write(f,'('+hex2(x)+'):');

    write(f,' '+hex2(rg.x[x]));
  end;
  writeln(f);
end;

procedure dumpregs(var f:text);
var x:word;
begin
  writeln(f,'Mode: '+hex2(md)+'h Pixels: '+istr(pixels)+' lines: '+istr(lins)
       +' bytes: '+istr(bytes)+' colors: '+istr(modecols[memmode]));
  writeln(f);
  for x:=$3C0 to $3CF do write(' '+hex2(stdregs[x]));
  writeln(f);
  for x:=$3D0 to $3DF do write(' '+hex2(stdregs[x]));
  writeln(f);
  write(f,'03C0:');
  for x:=0 to 31 do
  begin
    if x=25 then
    begin
      writeln(f);
      write(f,'(19):');
    end;
    write(f,' '+hex2(attregs[x]));
  end;
  writeln(f);
  wrregs(f,seqregs);
  wrregs(f,grcregs);
  wrregs(f,crtcregs);
  if xxregs.base<>0 then wrregs(f,xxregs);
  writeln(f);
end;



procedure plotchar(x,y,ch:word);
begin
  mem[bseg:(y*wid+x) shl 1]:=ch;
end;

procedure plotchat(x,y,ch,at:word);
begin
  memw[bseg:(y*wid+x) shl 1]:=at shl 8+ch;
end;

procedure plotstr(x,y:word;s:string);
var z:word;
begin
  for z:=1 to length(s) do
    plotchar(x+z-1,y,ord(s[z]));
end;

begin
  for md:=$14 to $7f do
  begin
    textmode(3);
    gotoxy(10,10);
    write('Testing mode: '+hex2(md));
    delay(500);
    vio(md);
    if mem[0:$449]=md then
    begin
      for x:=$3C2 to $3DF do stdregs[x]:=inp(x);
      x:=inp($3DA);
      stdregs[$3C0]:=inp($3C0);
      for x:=0 to 31 do attregs[x]:=rdinx($3C0,x);
      x:=rdinx($3C0,$30);
      dumprg(crtc,crtcregs);
      dumprg($3C4,seqregs);
      dumprg($3CE,grcregs);
      case chip of
        __chips451,__chips452,__chips453:dumprg(crtc+2,xxregs);
      else xxregs.base:=0;
      end;
      m:=grcregs.x[6];
      case (m shr 2) and 3 of
      0,1:bseg:=$a000;
        2:bseg:=$b000;
        3:bseg:=$b800;
      end;
      if odd(m) then
      begin  {graf mode}
        lins:=crtcregs.x[$12]+1;
        x:=crtcregs.x[7];
        if (x and 2)<>0 then inc(lins,256);
        if (x and 64)<>0 then inc(lins,512);
        pixels:=(crtcregs.x[1]+1)*8;

        wid:=crtcregs.x[$13];
        wordadr:=2;
        if (crtcregs.x[$14] and 64)<>0 then wordadr:=8
        else if (crtcregs.x[$17] and 64)=0 then wordadr:=4;
        case chip of
         __p2000:if (grcregs.x[$13] and 64)<>0 then
                 begin
                   wordadr:=wordadr shr 1;
                   if (grcregs.x[$21] and 32)<>0 then inc(wid,256);
                 end;
      __cirrus54:begin
                   if (crtcregs.x[$1B] and 16)<>0 then inc(wid,256);
                   if (crtcregs.x[$1A] and 1)<>0 then lins:=lins*2;
                 end;
        __tseng4:if (crtcregs.x[$3f] and 128)<>0 then inc(wid,256);
        end;
        x:=seqregs.x[4];
        if (x and 8)<>0 then  {256 color}
        begin
          memmode:=_p256;
          if dactype>_dac8 then
          begin
            dactocomm;
            x:=inp($3c6);

            if x>127 then memmode:=_p32k;
            case dactype of
              _dac16:if (x and 64)<>0 then memmode:=_p64k;
          (*  _dacss24:if x=$8e then
                     begin
                       memmode:=_p16m;
                       pixels:=pixels*3;
                     end;  *)
             _dacatt:case (x and $60) of
                       $40:memmode:=_p64k;
                       $60:memmode:=_p16m;
                     end;
           _dacadac1:case x of
                       $E1:memmode:=_p64k;
                       $E5:memmode:=_p16m;
                       $F0:memmode:=_p32k;
                     end;
            end;
            dactopel;
          end;
        end
       { else if (x and 4)<>0 then
        begin
          memmode:=_pl4;
          bytes:=wid;
        end }
        else memmode:=_pl16;
        bytes:=wid*wordadr;
        case memmode of               {Adjust for HiColor}
    _p32k,_p64k:pixels:=pixels div 2;
          _p16m:pixels:=pixels div 3;
        end;
        if (pixels>800) and (pixels>=2*lins) then  {adjust for interlace}
          lins:=lins*2;

        repeat
          oldbytes:=bytes;

          if setmode(md) then
          begin
            case colbits[memmode] of
              15:s:='32K';
              16:s:='64K';
              24:s:='16M';
            else s:=istr(modecols[memmode]);
            end;
            drawtestpattern('Mode: '+hex2(md)+' ('+istr(pixels)+'x'+istr(lins)+' '
                     +s+' col) '+istr(bytes)+' bytes.');
          end;

          case readkey of
           #0:begin
                c:=readkey;
                case c of
                  #73:bytes:=bytes shl 1;
                  #81:bytes:=bytes shr 1;
                  #72:inc(bytes);
                  #80:dec(bytes);
                end;
              end;
      'd','D':begin
                bytes:=oldbytes;
                textmode($103);
                dumpregs(output);
                if readkey='' then;
              end;
      'f','F':begin
                bytes:=oldbytes;
                assign(ofil,'register.vga');
                {$i-}
                append(ofil);
                {$i+}
                if ioresult<>0 then rewrite(ofil);
                dumpregs(ofil);
                close(ofil);
              end;
          end;
        until bytes=oldbytes;
      end
      else begin {text mode}
        for x:=0 to 16383 do
          memw[bseg:x+x]:=$720;
        wid:=memw[0:$44a];
        for x:=0 to wid-1 do
        begin
          plotchar(x,0,(x mod 10)+ord('0'));
          if (x mod 10)=0 then
            plotchar(x,1,((x div 10) mod 10)+ord('0'));
        end;
        hig:=mem[0:$484];
        for x:=0 to hig do
        begin
          plotchar(0,x,(x mod 10)+ord('0'));
          if (x mod 10)=0 then
            plotchar(1,x,((x div 10) mod 10)+ord('0'));
        end;
        plotstr(5,5,'Testing mode '+hex2(md)+'h: '+istr(wid)+'x'+istr(hig+1));
        for x:=0 to 255 do
          plotchat(x and 15+10,x shr 4+7,65,x);
        if readkey='' then;
        x:=x;
      end;
    end;
  end;
  textmode(3);
end;



procedure testvesamodes;          {Test VESA modes}
type
  modelist=array[1..100] of word;
var
  vesahrec:record
             sign:longint;
             version:word;
             oemname:^char;
             capabilities:longint;
             list:^modelist;
             xx:array[1..256] of byte;  {Might be filled by AX=4F00h}
           end;
  mode,x,y,novesamodes:word;
  oldchip:chips;
  c:char;

procedure tmode(m:word);
begin
  vesamodeinfo(m);
  pixels :=vesarec.width;
  lins   :=vesarec.height;
  bytes  :=vesarec.bytes;
  if setmode(m) then testvmode;
end;


begin
  oldchip:=chip;
  chip:=__vesa;
  rp.es:=seg(vesahrec);
  rp.di:=ofs(vesahrec);
  vesahrec.sign:=$41534556;
  vio($4f00);
  mode:=1;

     {S3 VESA driver can return wrong segment if run with QEMM}
  IF {(oldchip=__s3) and} (seg(vesahrec.list^)=$e000) then
    vesahrec.list:=ptr($c000,ofs(vesahrec.list^));
  textmode($103);
  writeln('Modes:');
  writeln;
  while vesahrec.list^[mode]<>$ffff do
  begin
    vesamodeinfo(vesahrec.list^[mode]);
    writeln('  '+chr(mode+64)+' '+hex4(vesahrec.list^[mode])+'h '
           +istr(vesarec.width)+'x'+istr(vesarec.height)+' '
           +mdtxt[memmode]);

    inc(mode);
  end;
  novesamodes:=mode;
  writeln;
  writeln('  *  All modes');

  writeln;
  c:=upcase(readkey);
  for mode:=1 to novesamodes do
    if (c='*') or (c=chr(mode+64)) then
      tmode(vesahrec.list^[mode]);
  chip:=oldchip;
  textmode(3);
  clrscr;
end;


var
  stop:boolean;


procedure loadmodes;              {Load extended modes for this chip}
var
  t:text;
  s,pat:string;
  md,x,xres,yres,err,mreq,byt:word;


function unhex(s:string):word;
var x:word;
begin
  for x:=1 to 4 do
    if s[x]>'9' then
      s[x]:=chr(ord(s[x]) and $5f-7);
  unhex:=(((word(ord(s[1])-48) shl 4
         +  word(ord(s[2])-48)) shl 4
         +  word(ord(s[3])-48)) shl 4
         +  word(ord(s[4])-48));
end;

function mmode(s:string):mmods;
var x:mmods;
begin
  for x:=_text to _p16m do
    if s=mmodenames[x] then mmode:=x;

end;

begin
  nomodes:=0;
  pat:='['+header[chip]+']';
  assign(t,'whatvga.lst');
  reset(t);
  s:=' ';
  while (not eof(t)) and (s<>pat) do readln(t,s);
  s:=' ';
  readln(t,s);
  while (s[1]<>'[') and (s<>'') do
  begin
    md:=unhex(copy(s,1,4));
    memmode:=mmode(copy(s,6,4));
    val(copy(s,11,5),xres,err);
    val(copy(s,17,4),yres,err);
    case memmode of
      _text,_text4:bytes:=xres*2;
 _pl2e, _herc,_cga2,_pl2:bytes:=xres shr 3;
    _pk4,_pl4,_cga4:bytes:=xres shr 4;
       _pl16,_pk16:bytes:=xres shr 1;
             _p256:bytes:=xres;
       _p32k,_p64k:bytes:=xres*2;
             _p16m:bytes:=xres*3;
    else
    end;
    case dactype of
        _dac8:if memmode>_p256 then memmode:=_text;
       _dac15:if memmode>_p32k then memmode:=_text;
       _dac16:if memmode=_p16m then memmode:=_text;
     _dacss24:if memmode=_p64k then memmode:=_text;
    end;
    val(copy(s,22,5),byt,err);
    if (err=0) and (byt>0) then bytes:=byt;
    if err<>0 then mreq:=(longint(bytes)*yres+1023) div 1024;
    case memmode of
      _pl16:bytes:=xres shr 3;
    end;
    if (memmode>_text4) and (mm>=mreq) then
    begin
      inc(nomodes);
      modetbl[nomodes].xres:=xres;
      modetbl[nomodes].yres:=yres;
      modetbl[nomodes].md:=md;
      modetbl[nomodes].bytes:=bytes;
      modetbl[nomodes].memmode:=memmode;
    end;
    readln(t,s);
  end;
  close(t);
end;


var
  chp,force_chip:chips;
  s:string;
  force_mm:word;
  err,x:word;


begin
  fillchar(dotest,sizeof(dotest),ord(true));   {allow test for all chips}
  force_mm:=0;
  force_chip:=__none;
  for x:=1 to paramcount do
  begin
    s:=paramstr(x);
    case s[1] of
     '-':begin
           s:=upstr(strip(copy(s,2,255)));
           for chp:=chips(1) to __none do
             if upstr(header[chp])=s then
               dotest[chp]:=false;
         end;
     '+':begin
           s:=upstr(strip(copy(s,2,255)));
           fillchar(dotest,sizeof(dotest),ord(false));
           for chp:=chips(1) to __none do
             if upstr(header[chp])=s then
             begin
               dotest[chp]:=true;
               force_chip:=chp;
             end;
         end;
     '=':val(copy(s,2,255),force_mm,err);
    end;
  end;

  findvideo;

  if force_chip<>__none then chip:=force_chip;
  if force_mm<>0 then mm:=force_mm;

  loadmodes;



  stop:=false;
  repeat
    textmode(3);
    writeln('WHATVGA v. 1.0    23/jan/93    Copyright 1991,92,93  Finn Thoegersen');
    writeln;

    write('Video system: ',video,' with '+istr(mm)+' Kbytes.');
    if _crt<>'' then write(' Monitor: '+_crt);
    writeln;
    if secondary<>'' then writeln('Secondary display: '+secondary);
    Write('Chipset: '+header[chip]);
    if name<>'' then write('  Name: '+name);
    writeln;
    if extra<>'' then writeln(extra);
    writeln('Dac: '+dacname);

    writeln;
    writeln('     1  Test Standard VGA modes');
    writeln('     2  Test Extended VGA modes');
    writeln('     3  Test scroll function');
    writeln('     4  Search for video modes');
    if vesa<>0 then
      writeln('     5  Test VESA modes.');
    writeln('     9  Stop');
    writeln;
    case readkey of
      '1':teststdvgamodes;
      '2':testvgamodes;
      '3':testscrollmodes;
      '4':searchformodes;
      '5':if vesa<>0 then testvesamodes;

      '9':stop:=true;
    end;

  until stop;


  vio(3);
end.