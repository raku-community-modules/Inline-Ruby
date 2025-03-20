#include <ruby.h>
#include <stdio.h>

/* Mostly these are just a way to deal with macros, wrapping them into a
 * function. They should probably be marked as 'inline' somehow to be more
 * better */

int raku_rb_type(VALUE obj) {
  return TYPE(obj);
}

int rb_to_raku_fixnum(VALUE obj) {
  return FIX2INT(obj);
}

char* rb_to_raku_string(VALUE obj) {
  return StringValuePtr(obj);
}

double rb_to_raku_dbl(VALUE obj) {
  return NUM2DBL(obj);
}

int raku_to_rb_int(int n) {
  return INT2FIX(n);
}

int raku_to_rb_str(char* s) {
  return rb_str_new2(s);
}

int raku_rb_array_length(VALUE obj) {
  return RARRAY_LENINT(obj);
}

VALUE raku_rb_funcallv(VALUE obj, ID method, int argc, const VALUE* argv) {
  return rb_funcall2(obj, method, argc, argv);
}

