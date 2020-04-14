---
title: Lua table的内部实现
date: 2020-02-20 18:47:55
tags:
---

## 整数类型的数组存放
一般情况下，整数类型的键都是放在数组里的，但是有2种特殊情况会被分配到hash表里。 

*n=键值区间2的指数。*

对于存放在数组有一个规则，每插入一个整数key时，都要判断包含当前key的区间[1, 2^n]里，是否满足table里所有整数类型key的数量大于2^(n - 1)，如果不成立则需要把这个key放在hash表里。这样设计，可以减少空间上的浪费，并可以进行空间的动态扩展。例如： 

<br>

a［0］ = 1, a［1］ = 1, a［5］= 1 
结果分析：数组大小4, hash大小1，a［5］本来是在8这个区间里的，但是有用个数3 < 8 / 2，所以a［5］放在了hash表里。

b［0］ = 1, b［1］ = 1, b［5］ = 1, b［6］ = 1, 
结果分析：数组大小4，hash大小2,有用个数4 < 8 / 2，所以b［5］,b［6］放在hash表里。

c［0］ = 1, c［1］ = 1, c［5］ = 1, c［6］ = 1, c［7］ = 1 
结果分析：数组大小8，hash大小0, 有用个数5 > 8 / 2。

数组a内有3个数，最大键值为5，key=5所在的键值空间为[1,8]，条件：所有整数类型key组数的数量为2^(3-1)=4，即数组分配4个int的内存空间，但a[5]并不在这个数组的存储内，它被分配在了hash表内存储。

之前a[]的理解是分配了3个内存int空间，不过这里看来不止3个内存空间了.

同理：b数组大小为4，key所在区间[1,8]，2^(3-1) = 4，所以a[5]、a[6]分配在hash表内。 


``` c++
static int computesizes (int nums[], int *narray) {
  int i;
  int twotoi;  /* 2^i */
  int a = 0;  /* 统计到2^i位置不为空的数量 */
  int na = 0;  /* 记录重新调整后的不为空的数量 */
  int n = 0;  /* 记录重新调整后的数组大小 */
  for (i = 0, twotoi = 1; twotoi/2 < *narray; i++, twotoi *= 2) {
    if (nums[i] > 0) {
      a += nums[i];
      if (a > twotoi/2) {  /* 判断当前的数量是否满足大于2^(i - 1) */
        n = twotoi;  /* optimal size (till now) */
        na = a;  /* all elements smaller than n will go to array part */
      }
    }
    if (a == *narray) break;  /* all elements already counted */
  }
  *narray = n;
  lua_assert(*narray/2 <= na && na <= *narray);
  return na;
}
```

<br>

## 参考
https://blog.csdn.net/heyuchang666/article/details/79305843