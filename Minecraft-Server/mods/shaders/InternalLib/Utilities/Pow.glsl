/* Copyright (C) Continuum Graphics - All Rights Reserved
 * Unauthorized copying of this file, via any medium is strictly prohibited
 * Proprietary and confidential
 * Written by Joseph Conover <support@continuum.graphics>, January 2018
 */

float pow2(float x){
    return x*x;
}

float pow3(float x){
    return x*x*x;
}

float pow4(float x){
    return pow2(pow2(x));
}

float pow5(float x){
    return pow4(x)*x;
}

float pow6(float x){
    return pow3(pow2(x));
}

float pow7(float x){
    return pow3(pow2(x))*x;
}

float pow8(float x){
    return pow2(pow4(x));
}