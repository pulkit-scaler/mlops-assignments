# Data Preparation with SageMaker Data Wrangler — Lab Question

---

## Description

In this lab, you will use **Amazon SageMaker Data Wrangler** to prepare the classic Iris dataset for an ML pipeline. You will load raw data from S3, apply three feature engineering transformations in the Data Wrangler visual interface, and export the processed dataset as a CSV to S3.

This simulates the first stage of a real-world MLOps pipeline: structured, reproducible data preparation whose output is versioned in S3 and handed off to downstream training jobs.

---

## Prerequisites

The following resources are pre-provisioned and available to you:

- **AWS Account** with:
  - An S3 bucket named `sagemaker-iris-lab-<your-account-id>` in `us-west-2`
  - The raw Iris dataset at `s3://sagemaker-iris-lab-<account-id>/raw-data/iris_raw.csv`
  - An IAM execution role: `sagemaker-lab-execution-role`

- **Pre-created files on your container:**
  - `/home/user/aws_iam_creds.json` — AWS credentials
  - `/home/user/lab_env.txt` — Environment details (bucket name, S3 paths)
  - `/home/user/sagemaker-iris-lab/setup_studio.sh` — Script to provision your Studio domain and user profile

---

## Tasks

### 1. Review Your Environment

```bash
cat /home/user/lab_env.txt
```

Note the values for `BUCKET_NAME` and `RAW_DATA_S3`.

---

### 2. Provision SageMaker Studio

SageMaker Studio requires a domain and user profile before you can open it. Run the provided script to create these now — this is the infrastructure provisioning step of an MLOps workflow.

```bash
cd ~/sagemaker-iris-lab
bash setup_studio.sh
```

The script will create a Studio domain (`iris-lab-domain`), wait for it to become **InService** (~5 minutes), then create your user profile. You will see output like:

```
Creating Studio domain (this takes ~5 min, please wait)...
  Status: Pending
  Status: Pending
  Status: InService
✓ Domain is InService!
✓ User profile: your-username
```

> **While you wait:** Navigate to the AWS Console → S3, find your bucket, and confirm `raw-data/iris_raw.csv` is present.

---

### 3. Open SageMaker Studio and Launch Data Wrangler

> ⚠️ **Region check first.** All lab resources are in `us-west-2`. Before opening SageMaker, confirm the region selector in the top-right of the AWS Console shows **US West (Oregon) us-west-2**. If it shows anything else, click it and switch to `us-west-2`.

Use this **direct link** to open SageMaker Studio in the correct region:

```
https://us-west-2.console.aws.amazon.com/sagemaker/home?region=us-west-2#/studio
```

1. Click **Open Studio** next to your user profile (or the domain `iris-lab-domain`)
2. Once Studio loads, locate the **Applications** grid at the top of the left sidebar and click **Canvas**
3. On the Canvas landing page you will see **Status: Stopped** — click **Run Canvas** and wait for it to start (this takes ~1–2 minutes)
4. Once Canvas is running, click **Prepare data** on the Canvas landing page — this opens Data Wrangler directly

> **Note:** If Canvas is already running (Status shows **Ready** or **In Service**), skip step 3 and go straight to **Prepare data**.

---

### 4. Connect to Your S3 Data Source

1. Browse to your lab bucket (`sagemaker-iris-lab-<your-account-id>`), navigate into `raw-data/`, select `iris_raw.csv`, and click **Import**

Data Wrangler opens a **node graph** on the **Data flow** tab with two nodes placed automatically:

- **Source** — S3: iris_raw.csv
- **Data types** — auto-detected column types

The dataset has 5 columns: `sepal_length`, `sepal_width`, `petal_length`, `petal_width`, `species`.

---

### 5. Apply Data Transformations

All transforms are added by clicking the **blue `+` button on the last node** in the flow graph, then selecting **Add transform**.

#### Transformation 1 — Handle Missing Values

1. Click the **blue `+`** on the **Data types** node → **Add transform**
2. Select **Handle missing** → **Drop missing**
3. Set **Input columns** to **all columns**
4. Click **Add**

#### Transformation 2 — Rename the Target Column

1. Click the **blue `+`** on the **Drop missing** node → **Add transform**
2. Select **Manage columns** → **Rename column**
3. **Input column:** `species` | **New name:** `target`
4. Click **Add**

#### Transformation 3 — Encode the Target Column

1. Click the **blue `+`** on the **Rename column** node → **Add transform**
2. Select **Encode categorical** → **Ordinal encode**
3. **Input columns:** select `target`
4. Click **Add**

When complete, your flow graph should show 5 nodes in a line:
**Source → Data types → Drop missing → Rename column → Ordinal encode**

The status bar at the bottom should confirm **Columns: 5 | Rows: 150**.

---

### 6. Export the Processed Dataset to S3

1. In the flow graph, click the **blue `+`** on the **Ordinal encode** (last) node
2. Select **Export** → **Export data to Amazon S3**
3. An **Export to Amazon S3** dialog opens. Fill in the fields:

   **Dataset name** — change the auto-generated name to something readable, e.g.:
   ```
   iris_processed
   ```

   **S3 location** — do **not** use the Browse button (it only shows existing prefixes, and `processed-data/` doesn't exist yet). Instead, type the URI directly into the **S3 location** text field:
   - First get your exact bucket name from the terminal:
     ```bash
     grep BUCKET_NAME ~/lab_env.txt | cut -d= -f2
     ```
   - Then type directly into the **S3 location** field (the red-bordered box in the main dialog):
     ```
     s3://<your-bucket-name>/processed-data/
     ```
     For example: `s3://sagemaker-iris-lab-835826344241/processed-data/`
   - Make sure there is a `/` between the bucket name and `processed-data`

4. Scroll down to **Advanced** → **Export settings** and confirm:
   - **File type:** CSV (already selected by default)
   - **Delimiter:** Comma (default)
   - **Compression:** None (default)

5. Scroll down and click **Export**

Monitor the job status:

- In the left sidebar, click **Data Wrangler** → switch to the **Jobs** tab
- Wait for the job status to show **Completed** before submitting

Verify the output in your terminal:
```bash
BUCKET=$(grep BUCKET_NAME ~/lab_env.txt | cut -d= -f2)
aws s3 ls s3://${BUCKET}/processed-data/ --recursive
```

---


## Summary Checklist

Before submitting, verify all of the following:

- [ ] AWS credentials valid
- [ ] S3 bucket `sagemaker-iris-lab-<account-id>` exists in `us-west-2`
- [ ] Raw dataset at `s3://.../raw-data/iris_raw.csv`
- [ ] Processed CSV exported to `s3://.../processed-data/`
- [ ] Processed CSV header contains `target` (not `species`) — rename applied
- [ ] `target` column contains only numeric values `0.0`, `1.0`, `2.0` — ordinal encode applied
- [ ] CSV has exactly 150 rows — drop missing retained all rows
- [ ] All 4 feature columns present: `sepal_length`, `sepal_width`, `petal_length`, `petal_width`
- [ ] Export job is **Completed** (verified in Data Wrangler → Jobs tab)

---

## Skills Practiced

- SageMaker Studio domain provisioning and infrastructure setup
- SageMaker Studio and Canvas navigation to reach Data Wrangler
- Loading datasets from S3 into Data Wrangler
- Feature engineering: missing value handling, column renaming, categorical encoding
- Exporting Data Wrangler flows and processed datasets to S3
- Verifying ML pipeline outputs via AWS CLI
