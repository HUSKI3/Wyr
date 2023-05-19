./wyr -s $1
if ! [ $? -ne 0 ]; then
    nasm -felf64 out.asm && ld out.o && ./a.out
fi