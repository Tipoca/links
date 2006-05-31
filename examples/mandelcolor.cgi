#!/home/s0567141/links/links
#!/Users/ezra/Development/links/links

precision = 10;
realUnit = precision;

fun zmagsq(c) {
  r = c.1; i = c.2;
  (r*r + i*i) / precision
}

fun zsquare(c) {
  r = c.1; i = c.2;
  ((r * r - i * i)/precision, (2 * r * i)/precision)
}

#fun zplus((r1, i1), (r2, i2)) {
#  (r1 + r2, i1 + i2)
#}
fun zplus(z1, z2) {
  (z1.1 + z2.1, z1.2 + z2.2)
}

the_limit = 16;

fun mandelloop(c, z, i) {
  if (zmagsq(c) > precision) {
    i
  } else if (i >= the_limit) {
    i
  } else {
    mandelloop(zplus(z, zsquare(c)), z, i+1)
  }
}

fun mandelbrot(r, i, limit) {
  # c <- z + c^2
  c = (0, 0);
  z = (r, i);
  result = mandelloop(c, z, 0);
  result
}

fun mandelmatrix(r, i, result, minr, maxr, mini, maxi) {
  if (i >= maxi) {
    result
  } else {
    if (r >= maxr) {
      if (i+1 >= maxi) result
      else 
        mandelmatrix(minr, i+1, []::result, minr, maxr, mini, maxi)
    } else {
      point = mandelbrot(r, i, the_limit);
      result = (point :: hd(result)) :: tl(result);
      mandelmatrix(r+1, i, result, minr, maxr, mini, maxi);
    }
  }
}

fun mandelregion(minr, maxr, mini, maxi) {
  mandelmatrix(minr, mini, [[]], minr, maxr, mini, maxi)
}

fun hexdigit(i) {
       if (i ==  0) "0"
  else if (i ==  1) "1"
  else if (i ==  2) "2"
  else if (i ==  3) "3"
  else if (i ==  4) "4"
  else if (i ==  5) "5"
  else if (i ==  6) "6"
  else if (i ==  7) "7"
  else if (i ==  8) "8"
  else if (i ==  9) "9"
  else if (i == 10) "a"
  else if (i == 11) "a"
  else if (i == 12) "b"
  else if (i == 13) "c"
  else if (i == 14) "d"
  else if (i == 15) "e"
  else #if (i == 16) 
    "f"
}

fun redshade(i, max) {
  if (i == max) "#000"
  else
    "#" ++ hexdigit(16*i/max) ++ "33";
  
}

fun pixeldiv(x, y, size, color) {
  <div id="{"p" ++ intToString(x) ++ "x" ++ intToString(y)}"
       style="width: {intToString(size)}px; 
              height: {intToString(size)}px;
              position: absolute;
              left: {intToString(x)}px;
              top: {intToString(y)}px;
              background-color: {redshade(color, the_limit)}"> </div>
}

fun zip(l1, l2) {
  if (l1 == [] || l2 == []) []
  else
    (hd(l1), hd(l2)) :: zip(tl(l1), tl(l2))
}

fun numbers(start, l) {
  if (l == []) []
  else
    (start, hd(l)) :: numbers(start+1, tl(l))
}

fun mandelBlock(pixSize, x, y, regionSize, r, i) {
  pixeldiv(x, y, pixSize/2, mandelbrot(r, i, the_limit)) ++
   pixeldiv(x+(pixSize/2), y, pixSize/2, mandelbrot(r+regionSize, i, the_limit)) ++
   pixeldiv(x, y+(pixSize/2), pixSize/2, mandelbrot(r, i+regionSize, the_limit))
}

fun dilation(mina, minb, maxa, maxb, minc, mind, maxc, maxd)
{
  ((maxc - minc) / (maxa - mina),
   (maxd - mind) / (maxb - minb));
}

fun mandelMadness(x, y, r, i, pixSize,
                  minx, miny, maxx, maxy,
                  mini, minr, maxi, maxr)
{
  (xdil, ydil) = dilation(minx, miny, maxx, maxy,
                          mini, minr, maxi, maxr);
  regionSize = pixSize * xdil;
  if (x >= maxx) {
    if (y >= maxy) {
      if (pixSize <= 1) {
        ()
      } else {
        mandelMadness(minx, miny, minr, mini, pixSize/2,
                      minx, miny, maxx, maxy, 
                      mini, minr, maxi, maxr)
      }
    } else {
      mandelMadness(minx, y+pixSize, minr, i+regionSize, pixSize,
                    minx, miny, maxx, maxy,
                    mini, minr, maxi, maxr);
    }
  } else {
    if (y >= maxy) {
      mandelMadness(minx, miny, minr, mini, pixSize/2,
                    minx, miny, maxx, maxy, 
                    mini, minr, maxi, maxr)
    } else {
      docElt = domGetDocumentRef();
      domAppendChild(mandelBlock(pixSize, x, y,
                                     regionSize, r, i), docElt);
      mandelMadness(x+pixSize, y, r+regionSize, i, pixSize,
                    minx, miny, maxx, maxy,
                    mini, minr, maxi, maxr);
    }
  }
}

fun goMandelMadness(mini, minr, maxi, maxr, pixelWidth)
{
  mandelMadness(0, 0, minr, mini, pixelWidth,
                0, 0, pixelWidth, pixelWidth, 
                mini, minr, maxi, maxr);
}

fun needless(n) {
  if (n <= 0) ()
  else needless(n-1);
}

fun main() client {
  domReplaceDocument(<body>
    <div id="p0x0" />
  </body>);
  needless(1000);   # gives the DOM process time to draw the initial div
  goMandelMadness(-1 * realUnit, -1 * realUnit, realUnit, realUnit, 128)
}

main()