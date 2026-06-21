import pandas as pd
import psycopg2
from sqlalchemy import create_engine, text
from sqlalchemy.types import VARCHAR, Text, Integer
import re
import numpy as np
import os

# Database connection parameters
DB_PARAMS = {
    'host': '10.54.18.142',
    'port': '5432',
    'database': 'dashboard',
    'user': 'dashboard',
    'password': 'T3lk0ms3l#2022*05',
    'options': f'-c search_path=app_hub'
}


def create_db_engine():
    """Create SQLAlchemy engine for database connection"""
    conn_string = f"postgresql://{DB_PARAMS['user']}:{DB_PARAMS['password']}@{DB_PARAMS['host']}:{DB_PARAMS['port']}/{DB_PARAMS['database']}"
    return create_engine(conn_string)


def convert_to_snake_case(name):
    """
    Convert a string to snake case format

    Args:
        name (str): String to convert

    Returns:
        str: Snake case formatted string
    """
    # Replace any non-alphanumeric characters with space
    s1 = re.sub('([^a-zA-Z0-9])', ' ', str(name))

    # Convert any capital case to space + lowercase
    s2 = re.sub('([A-Z][a-z]+)', r' \1', s1)

    # Convert any digit-alpha or alpha-digit to space between them
    s3 = re.sub('([a-z0-9])([A-Z])', r'\1 \2', s2)

    # Replace all spaces with underscore and convert to lowercase
    s4 = re.sub('[^a-zA-Z0-9]', '_', s3).lower()

    # Remove repeating underscores
    s5 = re.sub('_+', '_', s4)

    # Remove leading and trailing underscores
    return s5.strip('_')


def clean_data_for_ingestion(df, sheet_name):
    """
    Clean dataframe values by converting empty cells, NaN, '-' to None/NULL
    and normalize whitespace

    Args:
        df (pandas.DataFrame): Input dataframe to clean
        sheet_name (str): Name of the sheet being processed

    Returns:
        pandas.DataFrame: Cleaned dataframe
    """
    # Replace empty strings, whitespace-only strings, and '-' with None
    df = df.replace(r'^\s*$', None, regex=True)
    df = df.replace('-', None)

    # Replace NaN with None
    df = df.replace({np.nan: None})

    # Convert all non-None values to string and clean whitespace
    for col in df.columns:
        if col == 'id':  # Handle 'id' column specifically
            df[col] = df[col].apply(lambda x: int(
                x) if pd.notna(x) and x is not None else None)
        else:
            df[col] = df[col].apply(lambda x: re.sub(
                r'\s+', ' ', str(x).strip()) if pd.notna(x) and x is not None else None)

    return df


def merge_rows_by_status_division(df):
    """
    Merge rows with empty 'status_division' values into the previous row that has a value

    Args:
        df (pandas.DataFrame): Input dataframe

    Returns:
        pandas.DataFrame: Dataframe with merged rows
    """
    # Create a copy of the dataframe to avoid modifying the original
    df_merged = df.copy()

    # Initialize variables
    last_status_row = None
    rows_to_drop = []

    # Columns to skip during merge
    skip_columns = ['status_division', 'id']

    # Iterate through rows
    for idx, row in df_merged.iterrows():
        if pd.notna(row['status_division']) and str(row['status_division']).strip():
            # This row has a status_division value
            last_status_row = idx
        elif last_status_row is not None:
            # This row has no status_division value, merge with last_status_row
            for col in df_merged.columns:
                if col not in skip_columns:  # Skip status_division and id columns
                    current_value = row[col]
                    last_value = df_merged.at[last_status_row, col]

                    # If current row has a value and last row has a value, append with newline
                    if pd.notna(current_value) and pd.notna(last_value):
                        df_merged.at[last_status_row,
                                     col] = f"{last_value}\n{current_value}"
                    # If only current row has a value, use it
                    elif pd.notna(current_value):
                        df_merged.at[last_status_row, col] = current_value

            rows_to_drop.append(idx)

    # Drop the merged rows
    df_merged = df_merged.drop(rows_to_drop)

    print(
        f"Merged {len(rows_to_drop)} rows with empty 'status_division' values")
    return df_merged


def clean_column_names(df, sheet_name):
    """
    Clean column names by removing blank columns and converting to snake case

    Args:
        df (pandas.DataFrame): Input dataframe
        sheet_name (str): Name of the sheet being processed

    Returns:
        pandas.DataFrame: Dataframe with cleaned column names
    """
    # Get original column names
    original_columns = df.columns.tolist()

    # Filter out blank, NaN, or None column names and create a mapping
    valid_columns = {}
    for col in original_columns:
        # Skip columns with no header value (None, NaN, empty string, or whitespace)
        if pd.notna(col) and str(col).strip():
            # Skip the 'no' column for Security sheet
            if sheet_name == 'Security' and col == 'no':
                continue
            valid_columns[col] = convert_to_snake_case(col)
        else:
            print(f"Skipping column with no header value")

    # Select only columns with valid names and rename them
    df = df[list(valid_columns.keys())].rename(columns=valid_columns)

    # Add 'id' column for all sheets
    df.insert(0, 'id', range(1, len(df) + 1))

    print(
        f"Removed {len(original_columns) - len(valid_columns)} columns with invalid or blank names")
    return df


def merge_rows_with_empty_no(df):
    """
    Merge rows with empty 'no' values into the previous row that has a 'no' value

    Args:
        df (pandas.DataFrame): Input dataframe

    Returns:
        pandas.DataFrame: Dataframe with merged rows
    """
    # Create a copy of the dataframe to avoid modifying the original
    df_merged = df.copy()

    # Skip if 'no' column doesn't exist
    if 'no' not in df_merged.columns:
        print("No 'no' column found, skipping merge")
        return df_merged

    # Initialize variables
    last_no_row = None
    rows_to_drop = []

    # Iterate through rows
    for idx, row in df_merged.iterrows():
        if pd.notna(row['no']) and str(row['no']).strip():
            # This row has a 'no' value
            last_no_row = idx
        elif last_no_row is not None:
            # This row has no 'no' value, merge with last_no_row
            for col in df_merged.columns:
                if col != 'no':  # Skip the 'no' column
                    current_value = row[col]
                    last_value = df_merged.at[last_no_row, col]

                    # If current row has a value and last row has a value, append with newline
                    if pd.notna(current_value) and pd.notna(last_value):
                        df_merged.at[last_no_row,
                                     col] = f"{last_value}\n{current_value}"
                    # If only current row has a value, use it
                    elif pd.notna(current_value):
                        df_merged.at[last_no_row, col] = current_value

            rows_to_drop.append(idx)

    # Drop the merged rows
    df_merged = df_merged.drop(rows_to_drop)

    print(f"Merged {len(rows_to_drop)} rows with empty 'no' values")
    return df_merged


def get_column_types(df, sheet_name):
    """
    Define column types for database table creation

    Args:
        df (pandas.DataFrame): Input dataframe
        sheet_name (str): Name of the sheet being processed

    Returns:
        dict: Dictionary mapping column names to SQLAlchemy types
    """
    column_types = {}
    text_columns = ['description', 'url', 'ip_address',
                    'data_processing_management', 'source_data_application',
                    'tag_data_processing_management', 'output_application',
                    'output_application', 'asset_owner_department',
                    'apps_custody_pic', 'apps_custody_pic_user']

    for column in df.columns:
        if column == 'id':  # Handle 'id' column for both Security and Category sheets
            column_types[column] = Integer
        elif column in text_columns:
            column_types[column] = Text
        else:
            column_types[column] = VARCHAR(255)
    return column_types


def read_data_file(file_path, sheet_name=None):
    """
    Read data from either Excel or CSV file

    Args:
        file_path (str): Path to the data file
        sheet_name (str, optional): Sheet name for Excel files

    Returns:
        pandas.DataFrame: Loaded dataframe
    """
    file_extension = os.path.splitext(file_path)[1].lower()

    if file_extension in ['.xlsx', '.xls']:
        if sheet_name is None:
            raise ValueError("Sheet name is required for Excel files")
        return pd.read_excel(file_path, sheet_name=sheet_name)
    elif file_extension == '.csv':
        return pd.read_csv(file_path)
    else:
        raise ValueError(
            f"Unsupported file format: {file_extension}. Supported formats are .xlsx, .xls, and .csv")


def check_column_lengths(df):
    """
    Check and print the maximum length of values in each column

    Args:
        df (pandas.DataFrame): Input dataframe
    """
    print("\nChecking column lengths:")
    for column in df.columns:
        if df[column].dtype == 'object':  # Only check string columns
            max_length = df[column].astype(str).str.len().max()
            print(f"Column '{column}': max length = {max_length} characters")
            if max_length > 255:
                print(
                    f"WARNING: Column '{column}' has values longer than 255 characters!")


def ingest_data_to_db(file_path, sheet_name, table_name):
    """
    Ingest data from Excel or CSV file to PostgreSQL database

    Args:
        file_path (str): Path to the data file
        sheet_name (str): Name of the sheet (required for Excel files)
        table_name (str): Name of the target table in database
    """
    try:
        # Read data file
        print(f"Reading data from '{file_path}'...")
        df = read_data_file(file_path, sheet_name)

        # For Security sheet, convert 'Status Division' to snake case before merge
        if sheet_name == "Security":
            print("Processing Security sheet...")
            # Convert just the Status Division column name to snake case
            status_col = next(col for col in df.columns if col.lower().replace(
                ' ', '') == 'statusdivision')
            df = df.rename(columns={status_col: 'status_division'})
            # Perform merge
            df = merge_rows_by_status_division(df)
            print("Merged rows with empty status_division values")

        # Clean column names and remove blank columns (this will remove 'no' column for Security)
        df = clean_column_names(df, sheet_name)
        print("Cleaned column names and removed blank columns")

        # Clean data (convert empty cells and '-' to NULL)
        df = clean_data_for_ingestion(df, sheet_name)
        print("Cleaned data: converted empty cells, NaN, and '-' to NULL")

        # Check column lengths before ingestion
        check_column_lengths(df)

        # Create database engine
        engine = create_db_engine()

        # Get column types
        column_types = get_column_types(df, sheet_name)

        # Create table with primary key
        with engine.connect() as connection:
            # Drop existing table if it exists
            connection.execute(
                text(f"DROP TABLE IF EXISTS app_hub.{table_name}"))

            # Create table statement with explicit primary key
            create_table_sql = f"""
            CREATE TABLE app_hub.{table_name} (
                id INTEGER PRIMARY KEY,
                {', '.join(f"{col} {get_sql_type(dtype)}" 
                          for col, dtype in column_types.items() 
                          if col != 'id')}
            )
            """

            # Execute create table
            connection.execute(text(create_table_sql))
            connection.commit()

        # Write to database with specified column types
        print(f"\nIngesting data into table '{table_name}'...")
        try:
            # Ensure id column is integer
            df['id'] = df['id'].astype(int)

            df.to_sql(
                name=table_name,
                con=engine,
                schema='app_hub',
                if_exists='append',
                index=False,
                dtype=column_types
            )

            # Verify the table structure
            with engine.connect() as connection:
                result = connection.execute(text(f"""
                    SELECT column_name, data_type, 
                           (SELECT constraint_type 
                            FROM information_schema.table_constraints tc 
                            JOIN information_schema.constraint_column_usage cu 
                                ON cu.constraint_name = tc.constraint_name 
                            WHERE tc.table_name = c.table_name 
                            AND cu.column_name = c.column_name 
                            AND tc.constraint_type = 'PRIMARY KEY') as constraint_type
                    FROM information_schema.columns c
                    WHERE table_schema = 'app_hub' 
                    AND table_name = '{table_name}'
                    ORDER BY ordinal_position;
                """))

                print(f"\nTable structure for {table_name}:")
                for row in result:
                    constraint = "PRIMARY KEY" if row[2] == "PRIMARY KEY" else ""
                    print(f"Column: {row[0]}, Type: {row[1]} {constraint}")

            print(f"\nSuccessfully ingested {len(df)} rows into {table_name}")

        except Exception as e:
            print(f"Error during data ingestion: {str(e)}")
            raise

    except Exception as e:
        print(f"\nError occurred: {str(e)}")
        raise


def get_sql_type(sqlalchemy_type):
    """Convert SQLAlchemy type to SQL type string"""
    if isinstance(sqlalchemy_type, Integer):
        return "INTEGER"
    elif sqlalchemy_type == Text:
        return "TEXT"
    else:
        return "VARCHAR(255)"


def main():
    # Replace this with your data file path
    data_file_security = "NDAP App Catalogue_v2.xlsx"  # or "your_file.csv"
    data_file_catalogue = "NDAP_App_Catalogue_21032025_v2.xlsx"  # or "your_file.csv"

    # For Excel files, specify sheet names
    ingest_data_to_db(data_file_catalogue, "Catalogue", "ndap_catalogue_app_2")
    # ingest_data_to_db(
    #     data_file_security, "Security", "ndap_security_app")

    # For CSV files, you can use the same function but with sheet_name=None
    # ingest_data_to_db("your_file.csv", None, "your_table")


if __name__ == "__main__":
    main()
