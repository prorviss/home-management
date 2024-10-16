# Stage 1: Build the Go app
FROM golang:latest AS builder

# Set the working directory inside the container
WORKDIR /app

# Copy go mod and sum files
COPY go.mod go.sum ./

# Download all the dependencies
RUN go mod download

# Copy the source code into the container
COPY . .

# Build the Go app
RUN go build -o /bin/main ./main.go

CMD ["/bin/main"]