# gen_coe.py
# uart_hello_words.memh → uart_hello.coe 변환

input_file  = "uart_hello_words.memh"
output_file = "uart_hello.coe"

with open(input_file) as f:
    words = [line.strip() for line in f if line.strip()]

with open(output_file, "w") as f:
    f.write("memory_initialization_radix=16;\n")
    f.write("memory_initialization_vector=\n")
    for i, w in enumerate(words):
        if i < len(words) - 1:
            f.write(f"{w},\n")
        else:
            f.write(f"{w};\n")

print(f"완료: {output_file} ({len(words)}개 워드)")
