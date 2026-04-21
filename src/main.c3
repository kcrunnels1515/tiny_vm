module tiny_vm;

import std::io;

fn int factorial(int prev_res, int n) {
    if (n == 0) {
        return prev_res;
    } else {
        return factorial(n*prev_res, n-1);
    }
}

fn int main(String[] args)
{
	io::printfn("Factorial 15: %d", factorial(1, 15));
	return 0;
}
