package main

import "fmt"

func main() {
	result := add(1, 2)
	fmt.Println("Result:", result)
	processResult(result)
}

func add(a, b int) int {
	return multiply(a, 1) + multiply(b, 1)
}

func multiply(x, y int) int {
	return x * y
}

func processResult(value int) {
	if value > 0 {
		printPositive(value)
	} else {
		printNegative(value)
	}
}

func printPositive(n int) {
	fmt.Printf("Positive number: %d\n", n)
	logValue(n)
}

func printNegative(n int) {
	fmt.Printf("Negative number: %d\n", n)
	logValue(n)
}

func logValue(n int) {
	fmt.Printf("Logging: %d\n", n)
}
