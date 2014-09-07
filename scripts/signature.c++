/***************************************************************************
**                                                                        **
**   Copyright (C) 2009-2010 Nokia Corporation.                           **
**                                                                        **
**   Author: Ilya Dogolazky <ilya.dogolazky@nokia.com>                    **
**                                                                        **
**     This file is part of MeeGo 'tzdata' package                        **
**                                                                        **
**     It    is free software; you can redistribute it and/or modify      **
**     it under the terms of the GNU Lesser General Public License        **
**     version 2.1 as published by the Free Software Foundation.          **
**                                                                        **
**     It    is distributed in the hope that it will be useful, but       **
**     WITHOUT ANY WARRANTY;  without even the implied warranty  of       **
**     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.               **
**     See the GNU Lesser General Public License  for more details.       **
**                                                                        **
**   You should have received a copy of the GNU  Lesser General Public    **
**   License along with this file. If not, see http://www.gnu.org/licenses**
**                                                                        **
***************************************************************************/
#include <errno.h>
#include <stdlib.h>
#include <time.h>

#include <cassert>
#include <cstdio>
#include <cstring>
#include <string>
#include <iostream>
#include <vector>
#include <unistd.h>

using namespace std ;

const int year = 2010 ;

string process_tz(const char *base, const char *tz) ;

int main(int ac, char **av)
{
  vector<string> output ;

  if(ac<2 || av[1][0]!='/')
  {
    cerr << "Usage: " << av[0] << " /full/path/to/zone/directory zone...\n" ;
    return 1 ;
  }

  const char *base = av[1] ;

  for (int i=2; i<ac; ++i)
    output.push_back(process_tz(base, av[i])) ;

  for (int i=2; i<ac; ++i)
  {
    string key = av[i], value=output[i-2] ;
    if (value.empty())
      continue ;
    cout << key << ": " << value << "\n" ;
  }

  return 0 ;
}

string process_tz(const char *base, const char *timezone)
{
  string path = (string)base + "/" + timezone ;
  const char *tz = path.c_str() ;

  if (access(tz, F_OK) != 0)
  {
    fprintf(stderr, "%s: can't open file: %m\n", tz) ;
    return "" ;
  }

  int res_setenv = setenv("TZ", "UTC", true) ;
  tzset() ;

  if (res_setenv<0)
  {
    fprintf(stderr, "%s: can't set TZ to 'UTC': %m\n", tz) ;
    return "" ;
  }

  struct tm tm ;
  tm.tm_year = year - 1900 ;
  tm.tm_mon = 0 ; // January
  tm.tm_mday = 1 ;
  tm.tm_hour = 12 ;
  tm.tm_min = 34 ; // 12:34 1st of January GMT
  tm.tm_sec = 0 ;

  time_t begin = mktime(&tm) ;

  if(begin==(time_t)(-1))
  {
    fprintf(stderr, "%s: mktime failed: %m\n", tz) ;
    return "" ;
  }

  string tz_env = ":" ;
  tz_env += tz ;

  int res_setenv2 = setenv("TZ", tz_env.c_str(), true) ;
  tzset() ;

  if(res_setenv2<0)
  {
    fprintf(stderr, "%s: can't set as TZ: %m\n", tz) ;
    return "" ;
  }

  string signature ;

  for(int i=0; i<=1000; ++i)
  {
    time_t t = begin + i*24*60*60 ; // 1 Jan + i days
    struct tm result ;
    struct tm *res = localtime_r(&t, &result) ;
    if(res==NULL)
    {
      fprintf(stderr, "%s: localtime failed for time_t t=%lld: %m\n", tz, (long long)t) ;
      return "" ;
    }
    char uws = result.tm_isdst<0 ? 'u' : result.tm_isdst>0 ? 's' : 'w' ;
    // uws: unknown/winter/summer
    long off = result.tm_gmtoff ;
    bool minus = off<0 ? (off=-off, true) : false ;
    const int min15 = 15*60 ;
    if(off % min15 !=0)
    {
      fprintf(stderr, "%s: offset %ld is not divisible by 15min unit for time_t t=%lld\n", tz, off, (long long)t) ;
      return "" ;
    }
    int h = off / (60*60) ;
    int m = off % (60*60) ;
    m /= min15 ;
    assert(0<=m && m<=3) ;
    char oxyz = "oxyz"[m] ; // o:00 x:15 y:30 z:45
    char H = h<10 ? h+'0' : h-10+'A' ;
    if(minus)
      uws = toupper(uws), oxyz=toupper(oxyz) ;
    signature += uws ;
    signature += H ;
    signature += oxyz ;
  }

  return signature ;

  return 0 ;
}
