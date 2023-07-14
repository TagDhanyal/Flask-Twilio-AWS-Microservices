# Use an official Python runtime as the base image
FROM python:3.9

# Set the working directory in the container
WORKDIR /app

# Copy the requirements file to the working directory
COPY requirements.txt .

# Install the required Python packages
RUN pip install --no-cache-dir -r requirements.txt

# Copy the application code to the working directory
COPY purchase.py .

# Expose the port your application listens on
EXPOSE 5001

# Run the application
CMD ["python", "purchase.py"]