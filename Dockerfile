FROM node:20-alpine

# Install FFmpeg (Required for video remuxing and streaming)
RUN apk add --no-cache ffmpeg

# Set the working directory inside the container
WORKDIR /app

# Copy package.json and package-lock.json first to leverage Docker caching
COPY package*.json ./
# Install production dependencies
RUN npm install --omit=dev

# Copy the remaining project files
COPY . .

# Ensure persistent data directories exist
RUN mkdir -p data temp

# Define volumes mapping so metadata and caches aren't lost on restart
VOLUME ["/app/data", "/app/temp"]

# Expose the port (Defaults to 5000 in StreamFlix, adjust if your .env differs)
EXPOSE 5000

# Start the backend server
CMD ["npm", "start"]
