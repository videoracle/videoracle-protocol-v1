#!make
include .env

# -------------- DEPLOYMENT -------------- #

deploy: 
	npx hardhat run scripts/deploy.ts --network $(NETWORK)

#-------------- PLAYGROUND ----------------#

create-request:
	npx hardhat run scripts/playground/0-create-request.ts --network $(NETWORK)

submit-proof:
	npx hardhat run scripts/playground/1-submit-proof.ts --network $(NETWORK)

vote-proofs:
	npx hardhat run scripts/playground/2-vote-proofs.ts --network $(NETWORK)

setup: deploy create-request submit-proof vote-proofs