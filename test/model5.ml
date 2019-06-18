Printf.printf "1. = %f\n" 1.0;;
Printf.printf "0.1234567 = %f\n" 0.1234567;;
Printf.printf "0.1237 = %f\n" 0.1237;;
Printf.printf "-987654321.1234567 = %f\n" (-987654321.1234567);;
Printf.printf "+0.0 = %f\n" 0.0;;
Printf.printf "-0.0 = %f\n" (-0.0);;
Printf.printf "1./.0. = %f\n" (1.0 /. 0.0);;
Printf.printf "-1./.0. = %f\n" (-1.0 /. 0.0);;
Printf.printf "NaN = %f\n" nan;;

print_float 1.0;
print_newline ();
print_float 0.123456789876;
print_newline ();
print_float 0.12345678912;
print_newline ();
print_float 0.1234567;
print_newline ();
print_float 0.1237;
print_newline ();
print_float 0.0001;
print_newline ();
print_float 0.01;
print_newline ();
print_float (-987654321.1234567);
print_newline ();
print_float 0.0;
print_newline ();
print_float (-0.0);
print_newline ();
print_float (1.0 /. 0.0);
print_newline ();
print_float (-1.0 /. 0.0);
print_newline ();
print_float nan;
print_newline ();
